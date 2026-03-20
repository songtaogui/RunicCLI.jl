const _ARG_DECL_SPECS = Dict{Symbol,Any}(
    SYM_REQ     => (macro_name="@ARG_REQ",  kind=AK_OPTION,       style=:opt_required, has_type=true,  has_default=false, require_flags=true),
    SYM_DEF     => (macro_name="@ARG_DEF",  kind=AK_OPTION,       style=:opt_default,  has_type=true,  has_default=true,  require_flags=true),
    SYM_OPT     => (macro_name="@ARG_OPT",  kind=AK_OPTION,       style=:opt_optional, has_type=true,  has_default=false, require_flags=true),
    SYM_FLAG    => (macro_name="@ARG_FLAG", kind=AK_FLAG,         style=:flag,         has_type=false, has_default=false, require_flags=true),
    SYM_COUNT   => (macro_name="@ARG_COUNT",kind=AK_COUNT,        style=:count,        has_type=false, has_default=false, require_flags=true),
    SYM_MULTI   => (macro_name="@ARG_MULTI",kind=AK_OPTION_MULTI, style=:multi,        has_type=true,  has_default=false, require_flags=true),

    SYM_POS_REQ => (macro_name="@POS_REQ",  kind=AK_POS_REQUIRED, style=:pos_required, has_type=true,  has_default=false, require_flags=false),
    SYM_POS_DEF => (macro_name="@POS_DEF",  kind=AK_POS_DEFAULT,  style=:pos_default,  has_type=true,  has_default=true,  require_flags=false),
    SYM_POS_OPT => (macro_name="@POS_OPT",  kind=AK_POS_OPTIONAL, style=:pos_optional, has_type=true,  has_default=false, require_flags=false),
    SYM_POS_RST => (macro_name="@POS_REST", kind=AK_POS_REST,     style=:pos_rest,     has_type=true,  has_default=false, require_flags=false),
)

mutable struct _CompileCtx
    fields::Vector{Expr}
    option_parse_stmts::Vector{Expr}
    positional_parse_stmts::Vector{Expr}
    post_stmts::Vector{Expr}
    argdefs_expr::Vector{Expr}
    group_defs_excl::Vector{Vector{Symbol}}
    group_defs_incl::Vector{Vector{Symbol}}
    arg_requires_defs::Vector{ArgRequiresDef}
    arg_conflicts_defs::Vector{ArgConflictsDef}
    declared_names::Set{Symbol}
    name_kind::Dict{Symbol,ArgKind}
    seen_pos_rest::Bool
    flag_owner::Dict{String,Symbol}
end

_CompileCtx() = _CompileCtx(
    Expr[], Expr[], Expr[], Expr[], Expr[],
    Vector{Vector{Symbol}}(), Vector{Vector{Symbol}}(),
    ArgRequiresDef[], ArgConflictsDef[],
    Set{Symbol}(), Dict{Symbol,ArgKind}(),
    false, Dict{String,Symbol}()
)

function _coerce_symbol_identifier(x; allow_wrapped::Bool=true)::Union{Symbol,Nothing}
    if x isa Symbol
        return x
    elseif x isa QuoteNode && x.value isa Symbol
        return x.value
    elseif allow_wrapped && x isa Expr
        if x.head == :quote && length(x.args) == 1 && x.args[1] isa Symbol
            return x.args[1]
        elseif x.head in (:global, :local, :const) && length(x.args) == 1 && x.args[1] isa Symbol
            return x.args[1]
        end
    end
    return nothing
end

function _expect_name_symbol(x, macro_name::String, role::String)::Symbol
    s = _coerce_symbol_identifier(x; allow_wrapped=true)
    s !== nothing && return s
    throw(ArgumentError("$(macro_name) $(role) must be a Symbol identifier; got $(repr(x))"))
end

@inline function _collect_symbol_args(node::Expr, start_idx::Int, macro_name::String, role::String)
    syms = Symbol[]
    for i in start_idx:length(node.args)
        push!(syms, _expect_name_symbol(node.args[i], macro_name, role))
    end
    return syms
end

@inline function _ensure_min_count!(syms::Vector{Symbol}, n::Int, macro_name::String, what::String)
    length(syms) >= n || throw(ArgumentError("$(macro_name) requires at least $(n) $(what)"))
end

@inline function _ensure_no_duplicates!(syms::Vector{Symbol}, macro_name::String, what::String)
    length(unique(syms)) == length(syms) || throw(ArgumentError("$(macro_name) contains duplicate $(what)"))
end

function _extract_name_and_rest(node::Expr, name_idx::Int, macro_name::String, role::String)
    x = node.args[name_idx]
    tail = Any[node.args[i] for i in (name_idx + 1):length(node.args)]

    s = _coerce_symbol_identifier(x; allow_wrapped=true)
    if s !== nothing
        return s, tail
    end

    # compatibility path for legacy storage-like form
    if x isa Expr && x.head in (:global, :local, :const) && length(x.args) == 1
        a = x.args[1]
        if a isa String || (a isa QuoteNode && a.value isa String)
            return Symbol(String(x.head)), Any[a, tail...]
        end
    end

    throw(ArgumentError("$(macro_name) $(role) must be a Symbol identifier; got $(repr(x))"))
end

function _validate_flag!(f::String, macro_name::String)
    isempty(strip(f)) && throw(ArgumentError("$(macro_name) flag must not be empty"))
    occursin(r"\s", f) && throw(ArgumentError("$(macro_name) flag must not contain whitespace: $(repr(f))"))
    (startswith(f, "-") && f != "-" && f != "--") || throw(ArgumentError("$(macro_name) invalid flag: $(f)"))
    if startswith(f, "-") && !startswith(f, "--") && length(f) != 2
        throw(ArgumentError("$(macro_name) short flag must be exactly one character: $(f)"))
    end
end

function _register_flags!(ctx::_CompileCtx, flags::Vector{String}, owner::Symbol, macro_name::String)
    for f in flags
        _validate_flag!(f, macro_name)
        if haskey(ctx.flag_owner, f)
            throw(ArgumentError("duplicate flag detected: $(f) used by $(ctx.flag_owner[f]) and $(owner)"))
        end
        ctx.flag_owner[f] = owner
    end
end

function _extract_flags!(rest::Vector{Any}, macro_name::String)
    flags = String[]
    for x in rest
        if x isa String
            push!(flags, x)
        elseif x isa QuoteNode && x.value isa String
            push!(flags, x.value)
        else
            throw(ArgumentError("$(macro_name) flags must be String literals; got $(repr(x))"))
        end
    end
    return flags
end

function _parse_decl_pipeline!(ctx::_CompileCtx, spec, node::Expr)
    idx = 3

    T = nothing
    if spec.has_type
        idx > length(node.args) && throw(ArgumentError("$(spec.macro_name) expects a type parameter"))
        T = node.args[idx]
        idx += 1
    end

    dv = nothing
    if spec.has_default
        idx > length(node.args) && throw(ArgumentError("$(spec.macro_name) expects a default value"))
        dv = node.args[idx]
        idx += 1
    end

    idx > length(node.args) && throw(ArgumentError("$(spec.macro_name) expects an argument name"))
    nm, rest = _extract_name_and_rest(node, idx, spec.macro_name, "argument name")

    nm in ctx.declared_names && throw(ArgumentError("duplicate argument name: $(nm)"))

    help, help_name = _extract_help_meta!(rest; allow_help_name=true, macro_name=spec.macro_name)

    flags = String[]
    if spec.require_flags
        flags = _extract_flags!(rest, spec.macro_name)
        isempty(flags) && throw(ArgumentError("$(spec.macro_name) requires at least one flag"))
        _register_flags!(ctx, flags, nm, spec.macro_name)
    else
        isempty(rest) || throw(ArgumentError("$(spec.macro_name) supports only keyword metadata: help=\"...\", help_name=\"...\""))
    end

    push!(ctx.declared_names, nm)
    ctx.name_kind[nm] = spec.kind

    return (nm=nm, T=T, dv=dv, flags=flags, help=help, help_name=help_name, style=spec.style, kind=spec.kind)
end

function _emit_decl_opt_required!(ctx::_CompileCtx, d)
    nm, T, flags, help, help_name = d.nm, d.T, d.flags, d.help, d.help_name
    provided_sym = Symbol("_provided_", nm)
    tmp_sym = Symbol("_tmp_", nm)

    push!(ctx.fields, :($(nm)::$(T)))
    push!(ctx.option_parse_stmts, quote
        local $(tmp_sym) = $(_gr(:_pop_value_once!))(_opt_args, $(flags), $(string(nm)), allow_empty_option_value)
        local _raw = $(tmp_sym)[1]
        local $(provided_sym) = $(tmp_sym)[2]
        isnothing(_raw) && $(_gr(:_throw_arg_error))($(_gr(:_msg_missing_required_option))($(flags[end])))
        local $(nm)::$(T) = $(_gr(:_parse_value))($(T), _raw, $(string(nm)))
    end)
    push!(ctx.argdefs_expr, :($(_gr(:ArgDef))(kind=$(_gr(:AK_OPTION)), name=$(QuoteNode(nm)), T=$(T), flags=$(flags), required=true, help=$(help), help_name=$(help_name))))
end

function _emit_decl_opt_default!(ctx::_CompileCtx, d)
    nm, T, dv, flags, help, help_name = d.nm, d.T, d.dv, d.flags, d.help, d.help_name
    provided_sym = Symbol("_provided_", nm)
    tmp_sym = Symbol("_tmp_", nm)

    push!(ctx.fields, :($(nm)::$(T)))
    push!(ctx.option_parse_stmts, quote
        local $(tmp_sym) = $(_gr(:_pop_value_once!))(_opt_args, $(flags), $(string(nm)), allow_empty_option_value)
        local _raw = $(tmp_sym)[1]
        local $(provided_sym) = $(tmp_sym)[2]
        local $(nm)::$(T) = isnothing(_raw) ? $(_gr(:_convert_default))($(T), $(dv), $(string(nm))) : $(_gr(:_parse_value))($(T), _raw, $(string(nm)))
    end)
    push!(ctx.argdefs_expr, :($(_gr(:ArgDef))(kind=$(_gr(:AK_OPTION)), name=$(QuoteNode(nm)), T=$(T), flags=$(flags), default=$(dv), required=false, help=$(help), help_name=$(help_name))))
end

function _emit_decl_opt_optional!(ctx::_CompileCtx, d)
    nm, T, flags, help, help_name = d.nm, d.T, d.flags, d.help, d.help_name
    provided_sym = Symbol("_provided_", nm)
    tmp_sym = Symbol("_tmp_", nm)

    push!(ctx.fields, :($(nm)::Union{$(T),Nothing}))
    push!(ctx.option_parse_stmts, quote
        local $(tmp_sym) = $(_gr(:_pop_value_once!))(_opt_args, $(flags), $(string(nm)), allow_empty_option_value)
        local _raw = $(tmp_sym)[1]
        local $(provided_sym) = $(tmp_sym)[2]
        local $(nm)::Union{$(T),Nothing} = isnothing(_raw) ? nothing : $(_gr(:_parse_value))($(T), _raw, $(string(nm)))
    end)
    push!(ctx.argdefs_expr, :($(_gr(:ArgDef))(kind=$(_gr(:AK_OPTION)), name=$(QuoteNode(nm)), T=$(T), flags=$(flags), required=false, help=$(help), help_name=$(help_name))))
end

function _emit_decl_flag!(ctx::_CompileCtx, d)
    nm, flags, help, help_name = d.nm, d.flags, d.help, d.help_name
    flag_before_sym = Symbol("_flag_before_", nm)
    provided_sym = Symbol("_provided_", nm)

    push!(ctx.fields, :($(nm)::Bool))
    push!(ctx.option_parse_stmts, quote
        local $(flag_before_sym) = length(_opt_args)
        local $(nm)::Bool = $(_gr(:_pop_flag!))(_opt_args, $(flags))
        local $(provided_sym) = ($(flag_before_sym) != length(_opt_args))
    end)
    push!(ctx.argdefs_expr, :($(_gr(:ArgDef))(kind=$(_gr(:AK_FLAG)), name=$(QuoteNode(nm)), T=Bool, flags=$(flags), help=$(help), help_name=$(help_name))))
end

function _emit_decl_count!(ctx::_CompileCtx, d)
    nm, flags, help, help_name = d.nm, d.flags, d.help, d.help_name
    cnt_sym = Symbol("_cnt_", nm)
    provided_sym = Symbol("_provided_", nm)
    count_stmts = [:( $cnt_sym += $(_gr(:_pop_count!))(_opt_args, $(f)) ) for f in flags]

    push!(ctx.fields, :($(nm)::Int))
    push!(ctx.option_parse_stmts, quote
        local $cnt_sym = 0
        $(count_stmts...)
        local $(nm)::Int = $cnt_sym
        local $provided_sym = ($(nm) > 0)
    end)
    push!(ctx.argdefs_expr, :($(_gr(:ArgDef))(kind=$(_gr(:AK_COUNT)), name=$(QuoteNode(nm)), T=Int, flags=$(flags), help=$(help), help_name=$(help_name))))
end

function _emit_decl_multi!(ctx::_CompileCtx, d)
    nm, T, flags, help, help_name = d.nm, d.T, d.flags, d.help, d.help_name
    provided_sym = Symbol("_provided_", nm)

    push!(ctx.fields, :($(nm)::Vector{$(T)}))
    push!(ctx.option_parse_stmts, quote
        local _vals = $(_gr(:_pop_multi_values!))(_opt_args, $(flags), allow_empty_option_value)
        local $(provided_sym) = !isempty(_vals)
        local $(nm)::Vector{$(T)} = [ $(_gr(:_parse_value))($(T), v, $(string(nm))) for v in _vals ]
    end)
    push!(ctx.argdefs_expr, :($(_gr(:ArgDef))(kind=$(_gr(:AK_OPTION_MULTI)), name=$(QuoteNode(nm)), T=$(T), flags=$(flags), help=$(help), help_name=$(help_name))))
end

function _emit_decl_pos_required!(ctx::_CompileCtx, d)
    nm, T, help, help_name = d.nm, d.T, d.help, d.help_name
    provided_sym = Symbol("_provided_", nm)
    ctx.seen_pos_rest && throw(ArgumentError("@POS_REST must be the last positional declaration"))

    push!(ctx.fields, :($(nm)::$(T)))
    push!(ctx.positional_parse_stmts, quote
        isempty(_args) && $(_gr(:_throw_arg_error))($(_gr(:_msg_missing_required_positional))($(string(nm))))
        local $(provided_sym) = true
        local $(nm)::$(T) = $(_gr(:_parse_value))($(T), popfirst!(_args), $(string(nm)))
    end)
    push!(ctx.argdefs_expr, :($(_gr(:ArgDef))(kind=$(_gr(:AK_POS_REQUIRED)), name=$(QuoteNode(nm)), T=$(T), required=true, help=$(help), help_name=$(help_name))))
end

function _emit_decl_pos_default!(ctx::_CompileCtx, d)
    nm, T, dv, help, help_name = d.nm, d.T, d.dv, d.help, d.help_name
    provided_sym = Symbol("_provided_", nm)
    ctx.seen_pos_rest && throw(ArgumentError("@POS_REST must be the last positional declaration"))

    push!(ctx.fields, :($(nm)::$(T)))
    push!(ctx.positional_parse_stmts, quote
        local $(provided_sym) = !isempty(_args)
        local $(nm)::$(T) = isempty(_args) ? $(_gr(:_convert_default))($(T), $(dv), $(string(nm))) : $(_gr(:_parse_value))($(T), popfirst!(_args), $(string(nm)))
    end)
    push!(ctx.argdefs_expr, :($(_gr(:ArgDef))(kind=$(_gr(:AK_POS_DEFAULT)), name=$(QuoteNode(nm)), T=$(T), default=$(dv), help=$(help), help_name=$(help_name))))
end

function _emit_decl_pos_optional!(ctx::_CompileCtx, d)
    nm, T, help, help_name = d.nm, d.T, d.help, d.help_name
    provided_sym = Symbol("_provided_", nm)
    ctx.seen_pos_rest && throw(ArgumentError("@POS_REST must be the last positional declaration"))

    push!(ctx.fields, :($(nm)::Union{$(T),Nothing}))
    push!(ctx.positional_parse_stmts, quote
        local $(provided_sym) = !isempty(_args)
        local $(nm)::Union{$(T),Nothing} = isempty(_args) ? nothing : $(_gr(:_parse_value))($(T), popfirst!(_args), $(string(nm)))
    end)
    push!(ctx.argdefs_expr, :($(_gr(:ArgDef))(kind=$(_gr(:AK_POS_OPTIONAL)), name=$(QuoteNode(nm)), T=$(T), help=$(help), help_name=$(help_name))))
end

function _emit_decl_pos_rest!(ctx::_CompileCtx, d)
    nm, T, help, help_name = d.nm, d.T, d.help, d.help_name
    provided_sym = Symbol("_provided_", nm)
    ctx.seen_pos_rest && throw(ArgumentError("only one @POS_REST is allowed and it must be last"))
    ctx.seen_pos_rest = true

    push!(ctx.fields, :($(nm)::Vector{$(T)}))
    push!(ctx.positional_parse_stmts, quote
        local $(provided_sym) = !isempty(_args)
        local $(nm)::Vector{$(T)} = [ $(_gr(:_parse_value))($(T), x, $(string(nm))) for x in _args ]
        empty!(_args)
    end)
    push!(ctx.argdefs_expr, :($(_gr(:ArgDef))(kind=$(_gr(:AK_POS_REST)), name=$(QuoteNode(nm)), T=$(T), help=$(help), help_name=$(help_name))))
end

const _DECL_EMITTERS = Dict{Symbol,Function}(
    :opt_required => _emit_decl_opt_required!,
    :opt_default  => _emit_decl_opt_default!,
    :opt_optional => _emit_decl_opt_optional!,
    :flag         => _emit_decl_flag!,
    :count        => _emit_decl_count!,
    :multi        => _emit_decl_multi!,
    :pos_required => _emit_decl_pos_required!,
    :pos_default  => _emit_decl_pos_default!,
    :pos_optional => _emit_decl_pos_optional!,
    :pos_rest     => _emit_decl_pos_rest!,
)

function _emit_decl_codegen!(ctx::_CompileCtx, d)
    em = get(_DECL_EMITTERS, d.style, nothing)
    em === nothing && throw(ArgumentError("internal error: unsupported declaration style $(d.style)"))
    em(ctx, d)
end

function _validate_relations!(ctx::_CompileCtx)
    for grp in ctx.group_defs_excl, s in grp
        s in ctx.declared_names || throw(ArgumentError("@GROUP_EXCL references unknown argument: $(s)"))
        if get(ctx.name_kind, s, AK_OPTION) in (AK_POS_REQUIRED, AK_POS_DEFAULT, AK_POS_OPTIONAL, AK_POS_REST)
            throw(ArgumentError("@GROUP_EXCL supports only option-style arguments, got positional: $(s)"))
        end
    end

    for grp in ctx.group_defs_incl, s in grp
        s in ctx.declared_names || throw(ArgumentError("@GROUP_INCL references unknown argument: $(s)"))
        if get(ctx.name_kind, s, AK_OPTION) in (AK_POS_REQUIRED, AK_POS_DEFAULT, AK_POS_OPTIONAL, AK_POS_REST)
            throw(ArgumentError("@GROUP_INCL supports only option-style arguments, got positional: $(s)"))
        end
    end

    for rd in ctx.arg_requires_defs
        rd.anchor in ctx.declared_names || throw(ArgumentError("@ARG_REQUIRES references unknown argument: $(rd.anchor)"))
        if get(ctx.name_kind, rd.anchor, AK_OPTION) in (AK_POS_REQUIRED, AK_POS_DEFAULT, AK_POS_OPTIONAL, AK_POS_REST)
            throw(ArgumentError("@ARG_REQUIRES supports only option-style arguments, got positional: $(rd.anchor)"))
        end
        for s in rd.targets
            s in ctx.declared_names || throw(ArgumentError("@ARG_REQUIRES references unknown argument: $(s)"))
            if get(ctx.name_kind, s, AK_OPTION) in (AK_POS_REQUIRED, AK_POS_DEFAULT, AK_POS_OPTIONAL, AK_POS_REST)
                throw(ArgumentError("@ARG_REQUIRES supports only option-style arguments, got positional: $(s)"))
            end
        end
    end

    for cd in ctx.arg_conflicts_defs
        cd.anchor in ctx.declared_names || throw(ArgumentError("@ARG_CONFLICTS references unknown argument: $(cd.anchor)"))
        if get(ctx.name_kind, cd.anchor, AK_OPTION) in (AK_POS_REQUIRED, AK_POS_DEFAULT, AK_POS_OPTIONAL, AK_POS_REST)
            throw(ArgumentError("@ARG_CONFLICTS supports only option-style arguments, got positional: $(cd.anchor)"))
        end
        for s in cd.targets
            s in ctx.declared_names || throw(ArgumentError("@ARG_CONFLICTS references unknown argument: $(s)"))
            if get(ctx.name_kind, s, AK_OPTION) in (AK_POS_REQUIRED, AK_POS_DEFAULT, AK_POS_OPTIONAL, AK_POS_REST)
                throw(ArgumentError("@ARG_CONFLICTS supports only option-style arguments, got positional: $(s)"))
            end
        end
    end
end

function _compile_cmd_block(block::Expr)
    ctx = _CompileCtx()

    for node in _getmacrocalls(block)
        m = _getmacroname(node)
        m === nothing && throw(ArgumentError("unsupported DSL macro expression"))

        if m == SYM_GROUP
            syms = _collect_symbol_args(node, 3, "@GROUP_EXCL", "argument name")
            _ensure_min_count!(syms, 2, "@GROUP_EXCL", "argument names")
            _ensure_no_duplicates!(syms, "@GROUP_EXCL", "argument names")
            push!(ctx.group_defs_excl, syms)

        elseif m == SYM_GROUP_INCL
            syms = _collect_symbol_args(node, 3, "@GROUP_INCL", "argument name")
            _ensure_min_count!(syms, 2, "@GROUP_INCL", "argument names")
            _ensure_no_duplicates!(syms, "@GROUP_INCL", "argument names")
            push!(ctx.group_defs_incl, syms)

        elseif m == SYM_ARG_REQUIRES
            anchor = _expect_name_symbol(node.args[3], "@ARG_REQUIRES", "anchor argument")
            targets = _collect_symbol_args(node, 4, "@ARG_REQUIRES", "target argument")
            _ensure_min_count!(targets, 1, "@ARG_REQUIRES", "target arguments")
            anchor in targets && throw(ArgumentError("@ARG_REQUIRES anchor argument must not appear in targets"))
            _ensure_no_duplicates!(targets, "@ARG_REQUIRES", "target arguments")
            push!(ctx.arg_requires_defs, ArgRequiresDef(anchor=anchor, targets=targets))

        elseif m == SYM_ARG_CONFLICTS
            anchor = _expect_name_symbol(node.args[3], "@ARG_CONFLICTS", "anchor argument")
            targets = _collect_symbol_args(node, 4, "@ARG_CONFLICTS", "target argument")
            _ensure_min_count!(targets, 1, "@ARG_CONFLICTS", "target arguments")
            anchor in targets && throw(ArgumentError("@ARG_CONFLICTS anchor argument must not appear in targets"))
            _ensure_no_duplicates!(targets, "@ARG_CONFLICTS", "target arguments")
            push!(ctx.arg_conflicts_defs, ArgConflictsDef(anchor=anchor, targets=targets))

        elseif haskey(_ARG_DECL_SPECS, m)
            decl = _parse_decl_pipeline!(ctx, _ARG_DECL_SPECS[m], node)
            _emit_decl_codegen!(ctx, decl)

        elseif m == SYM_TEST
            nm, rest = _extract_name_and_rest(node, 3, "@ARG_TEST", "argument name")
            nm in ctx.declared_names || throw(ArgumentError("@ARG_TEST references unknown argument: $(nm)"))
            isempty(rest) && throw(ArgumentError("@ARG_TEST requires a validator function"))
            fn = rest[1]
            msg = if length(rest) >= 2
                rest[2] isa String || throw(ArgumentError("@ARG_TEST message must be a String literal"))
                rest[2]
            else
                "Argument test failed: $(nm)"
            end
            length(rest) <= 2 || throw(ArgumentError("@ARG_TEST accepts at most one message String"))

            push!(ctx.post_stmts, quote
                if !(isnothing($(nm)) || $(fn)($(nm)))
                    local _vname = try String(nameof($(fn))) catch; "validator" end
                    $(_gr(:_throw_arg_error))($(msg) * " (arg=$(string($(QuoteNode(nm)))), validator=" * _vname * ", value=" * repr($(nm)) * ")")
                end
            end)

        elseif m == SYM_STREAM
            nm, rest = _extract_name_and_rest(node, 3, "@ARG_STREAM", "argument name")
            nm in ctx.declared_names || throw(ArgumentError("@ARG_STREAM references unknown argument: $(nm)"))
            isempty(rest) && throw(ArgumentError("@ARG_STREAM requires a validator function"))
            fn = rest[1]
            msg = if length(rest) >= 2
                rest[2] isa String || throw(ArgumentError("@ARG_STREAM message must be a String literal"))
                rest[2]
            else
                "Streaming validation failed: $(nm)"
            end
            length(rest) <= 2 || throw(ArgumentError("@ARG_STREAM accepts at most one message String"))

            push!(ctx.post_stmts, quote
                local _vname = try String(nameof($(fn))) catch; "validator" end
                local _fails = String[]
                if $(nm) isa AbstractVector
                    for _v in $(nm)
                        if !$(fn)(_v)
                            push!(_fails, repr(_v))
                        end
                    end
                elseif !(isnothing($(nm)) || $(fn)($(nm)))
                    push!(_fails, repr($(nm)))
                end
                if !isempty(_fails)
                    $(_gr(:_throw_arg_error))($(msg) * " (arg=$(string($(QuoteNode(nm)))), validator=" * _vname * ", failed_values=[" * join(_fails, ", ") * "])")
                end
            end)
        else
            throw(ArgumentError("unsupported DSL macro: $(m)"))
        end
    end

    _validate_relations!(ctx)

    return ctx.fields,
           ctx.option_parse_stmts,
           ctx.positional_parse_stmts,
           ctx.post_stmts,
           ctx.argdefs_expr,
           ctx.group_defs_excl,
           ctx.group_defs_incl,
           ctx.arg_requires_defs,
           ctx.arg_conflicts_defs
end
