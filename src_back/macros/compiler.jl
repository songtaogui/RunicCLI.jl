function _expect_name_symbol(x, macro_name::String, role::String)::Symbol
    if x isa Symbol
        return x
    elseif x isa QuoteNode && x.value isa Symbol
        return x.value
    elseif x isa Expr
        if x.head == :quote && length(x.args) == 1
            q = x.args[1]
            if q isa Symbol
                return q
            end
        elseif x.head == :global && length(x.args) == 1 && x.args[1] isa Symbol
            return x.args[1]
        elseif x.head == :local && length(x.args) == 1 && x.args[1] isa Symbol
            return x.args[1]
        elseif x.head == :const && length(x.args) == 1 && x.args[1] isa Symbol
            return x.args[1]
        end
    end
    throw(ArgumentError("$(macro_name) $(role) must be a Symbol identifier; got $(repr(x))"))
end

function _extract_name_and_rest(node::Expr, name_idx::Int, macro_name::String, role::String)
    x = node.args[name_idx]
    tail = Any[node.args[i] for i in (name_idx + 1):length(node.args)]

    if x isa Symbol
        return x, tail
    elseif x isa QuoteNode && x.value isa Symbol
        return x.value, tail
    elseif x isa Expr
        if x.head == :quote && length(x.args) == 1 && x.args[1] isa Symbol
            return x.args[1], tail
        elseif x.head in (:global, :local, :const) && length(x.args) == 1
            a = x.args[1]
            if a isa Symbol
                return a, tail
            elseif a isa String || (a isa QuoteNode && a.value isa String)
                return Symbol(String(x.head)), Any[a, tail...]
            end
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

function _extract_cmd_meta(
    block::Expr;
    ctx::String,
    initial_description::String="",
    allow_subcommands::Bool=true
)::Tuple{NormalizedCmdMeta,Vector{Expr},Vector{NormalizedSubCmd}}
    nonmacro = _nonmacro_nodes(block)
    if !isempty(nonmacro)
        throw(ArgumentError("Only DSL macros are allowed inside $(ctx) block; found non-macro statement(s)"))
    end

    meta = NormalizedCmdMeta(description=initial_description)
    seen_usage = false
    seen_desc = !isempty(initial_description)
    seen_epilog = false
    seen_allow = false

    main_nodes = Expr[]
    normalized_sub_nodes = NormalizedSubCmd[]

    for node in _getmacrocalls(block)
        m = _getmacroname(node)

        if m == SYM_USAGE
            seen_usage && throw(ArgumentError("@CMD_USAGE is duplicated in $(ctx)"))
            length(node.args) >= 3 || throw(ArgumentError("@CMD_USAGE expects one String literal"))
            node.args[3] isa String || throw(ArgumentError("@CMD_USAGE expects a String literal"))
            meta = NormalizedCmdMeta(
                usage=node.args[3],
                description=meta.description,
                epilog=meta.epilog,
                allow_extra=meta.allow_extra
            )
            seen_usage = true

        elseif m == SYM_DESC
            seen_desc && throw(ArgumentError("@CMD_DESC is duplicated in $(ctx)"))
            length(node.args) >= 3 || throw(ArgumentError("@CMD_DESC expects one String literal"))
            node.args[3] isa String || throw(ArgumentError("@CMD_DESC expects a String literal"))
            meta = NormalizedCmdMeta(
                usage=meta.usage,
                description=node.args[3],
                epilog=meta.epilog,
                allow_extra=meta.allow_extra
            )
            seen_desc = true

        elseif m == SYM_EPILOG
            seen_epilog && throw(ArgumentError("@CMD_EPILOG is duplicated in $(ctx)"))
            length(node.args) >= 3 || throw(ArgumentError("@CMD_EPILOG expects one String literal"))
            node.args[3] isa String || throw(ArgumentError("@CMD_EPILOG expects a String literal"))
            meta = NormalizedCmdMeta(
                usage=meta.usage,
                description=meta.description,
                epilog=node.args[3],
                allow_extra=meta.allow_extra
            )
            seen_epilog = true

        elseif m == SYM_ALLOW
            seen_allow && throw(ArgumentError("@ALLOW_EXTRA is duplicated in $(ctx)"))
            meta = NormalizedCmdMeta(
                usage=meta.usage,
                description=meta.description,
                epilog=meta.epilog,
                allow_extra=true
            )
            seen_allow = true

        elseif m == SYM_SUB
            allow_subcommands || throw(ArgumentError("@CMD_SUB is not allowed inside $(ctx)"))
            length(node.args) >= 4 || throw(ArgumentError("@CMD_SUB expects \"name\" begin ... end or \"name\" \"desc\" begin ... end"))

            sub_name = node.args[3]
            sub_name isa String || throw(ArgumentError("@CMD_SUB name must be a String literal"))
            startswith(sub_name, "-") && throw(ArgumentError("@CMD_SUB name must not start with '-'"))

            sub_desc = ""
            sub_block = nothing

            if length(node.args) == 4
                sub_block = node.args[4]
            elseif length(node.args) == 5
                node.args[4] isa String || throw(ArgumentError("@CMD_SUB second argument must be a String description when 5 arguments are used"))
                sub_desc = node.args[4]
                sub_block = node.args[5]
            else
                throw(ArgumentError("@CMD_SUB expects \"name\" begin ... end or \"name\" \"desc\" begin ... end"))
            end

            (sub_block isa Expr && sub_block.head == :block) || throw(ArgumentError("@CMD_SUB body must be a begin...end block"))

            sub_ctx = "@CMD_SUB \"$(sub_name)\""
            sub_meta, _, _ = _extract_cmd_meta(sub_block; ctx=sub_ctx, initial_description=sub_desc, allow_subcommands=false)

            any(s.name == sub_name for s in normalized_sub_nodes) && throw(ArgumentError("duplicate subcommand name: $(sub_name)"))

            push!(normalized_sub_nodes, NormalizedSubCmd(
                name=sub_name,
                description=sub_meta.description,
                usage=sub_meta.usage,
                epilog=sub_meta.epilog,
                block=sub_block,
                allow_extra=sub_meta.allow_extra
            ))
        else
            push!(main_nodes, node)
        end
    end

    return meta, main_nodes, normalized_sub_nodes
end

function _validate_cmd_spec!(spec::NormalizedCmdSpec)
    declared_names = Set{Symbol}()
    name_kind = Dict{Symbol,ArgKind}()
    seen_pos_rest = false
    flag_owner = Dict{String,Symbol}()

    local is_positional_name(s::Symbol) = name_kind[s] in (AK_POS_REQUIRED, AK_POS_DEFAULT, AK_POS_OPTIONAL, AK_POS_REST)

    for a in spec.args
        a.name in declared_names && throw(ArgumentError("duplicate argument name: $(a.name)"))
        push!(declared_names, a.name)
        name_kind[a.name] = a.kind

        if a.kind == AK_POS_REST
            seen_pos_rest && throw(ArgumentError("only one @POS_REST is allowed and it must be last"))
            seen_pos_rest = true
        elseif seen_pos_rest
            throw(ArgumentError("@POS_REST must be the last positional declaration"))
        end

        for f in a.flags
            _validate_flag!(f, string(a.name))
            if haskey(flag_owner, f)
                throw(ArgumentError("duplicate flag detected: $(f) used by $(flag_owner[f]) and $(a.name)"))
            end
            flag_owner[f] = a.name
        end
    end

    for grp in spec.mutual_exclusion_groups
        length(grp) < 2 && throw(ArgumentError("@GROUP_EXCL requires at least two argument names"))
        length(unique(grp)) != length(grp) && throw(ArgumentError("@GROUP_EXCL contains duplicate argument names"))
        for s in grp
            s in declared_names || throw(ArgumentError("@GROUP_EXCL references unknown argument: $(s)"))
            if is_positional_name(s)
                throw(ArgumentError("@GROUP_EXCL supports only option-style arguments, got positional: $(s)"))
            end
        end
    end

    for grp in spec.mutual_inclusion_groups
        length(grp) < 2 && throw(ArgumentError("@GROUP_INCL requires at least two argument names"))
        length(unique(grp)) != length(grp) && throw(ArgumentError("@GROUP_INCL contains duplicate argument names"))
        for s in grp
            s in declared_names || throw(ArgumentError("@GROUP_INCL references unknown argument: $(s)"))
            if is_positional_name(s)
                throw(ArgumentError("@GROUP_INCL supports only option-style arguments, got positional: $(s)"))
            end
        end
    end

    for rd in spec.arg_requires
        rd.anchor in declared_names || throw(ArgumentError("@ARG_REQUIRES references unknown argument: $(rd.anchor)"))
        isempty(rd.targets) && throw(ArgumentError("@ARG_REQUIRES requires at least one target argument"))
        rd.anchor in rd.targets && throw(ArgumentError("@ARG_REQUIRES anchor argument must not appear in targets"))
        length(unique(rd.targets)) != length(rd.targets) && throw(ArgumentError("@ARG_REQUIRES contains duplicate target arguments"))
        if name_kind[rd.anchor] in (AK_POS_REQUIRED, AK_POS_DEFAULT, AK_POS_OPTIONAL, AK_POS_REST)
            throw(ArgumentError("@ARG_REQUIRES supports only option-style arguments, got positional: $(rd.anchor)"))
        end
        for s in rd.targets
            s in declared_names || throw(ArgumentError("@ARG_REQUIRES references unknown argument: $(s)"))
            if is_positional_name(s)
                throw(ArgumentError("@ARG_REQUIRES supports only option-style arguments, got positional: $(s)"))
            end
        end
    end

    for cd in spec.arg_conflicts
        cd.anchor in declared_names || throw(ArgumentError("@ARG_CONFLICTS references unknown argument: $(cd.anchor)"))
        isempty(cd.targets) && throw(ArgumentError("@ARG_CONFLICTS requires at least one target argument"))
        cd.anchor in cd.targets && throw(ArgumentError("@ARG_CONFLICTS anchor argument must not appear in targets"))
        length(unique(cd.targets)) != length(cd.targets) && throw(ArgumentError("@ARG_CONFLICTS contains duplicate target arguments"))
        if name_kind[cd.anchor] in (AK_POS_REQUIRED, AK_POS_DEFAULT, AK_POS_OPTIONAL, AK_POS_REST)
            throw(ArgumentError("@ARG_CONFLICTS supports only option-style arguments, got positional: $(cd.anchor)"))
        end
        for s in cd.targets
            s in declared_names || throw(ArgumentError("@ARG_CONFLICTS references unknown argument: $(s)"))
            if is_positional_name(s)
                throw(ArgumentError("@ARG_CONFLICTS supports only option-style arguments, got positional: $(s)"))
            end
        end
    end
end

const _ARG_SCHEMA = Dict{Symbol,NamedTuple}(
    SYM_REQ => (
        kind=AK_OPTION,
        macro_name="@ARG_REQ",
        type_idx=3,
        default_idx=nothing,
        name_idx=4,
        require_flags=true,
        positional=false,
        required=true,
        has_default=false,
    ),
    SYM_DEF => (
        kind=AK_OPTION,
        macro_name="@ARG_DEF",
        type_idx=3,
        default_idx=4,
        name_idx=5,
        require_flags=true,
        positional=false,
        required=false,
        has_default=true,
    ),
    SYM_OPT => (
        kind=AK_OPTION,
        macro_name="@ARG_OPT",
        type_idx=3,
        default_idx=nothing,
        name_idx=4,
        require_flags=true,
        positional=false,
        required=false,
        has_default=false,
    ),
    SYM_FLAG => (
        kind=AK_FLAG,
        macro_name="@ARG_FLAG",
        type_idx=nothing,
        default_idx=nothing,
        name_idx=3,
        require_flags=true,
        positional=false,
        required=false,
        has_default=false,
    ),
    SYM_COUNT => (
        kind=AK_COUNT,
        macro_name="@ARG_COUNT",
        type_idx=nothing,
        default_idx=nothing,
        name_idx=3,
        require_flags=true,
        positional=false,
        required=false,
        has_default=false,
    ),
    SYM_MULTI => (
        kind=AK_OPTION_MULTI,
        macro_name="@ARG_MULTI",
        type_idx=3,
        default_idx=nothing,
        name_idx=4,
        require_flags=true,
        positional=false,
        required=false,
        has_default=false,
    ),
    SYM_POS_REQ => (
        kind=AK_POS_REQUIRED,
        macro_name="@POS_REQ",
        type_idx=3,
        default_idx=nothing,
        name_idx=4,
        require_flags=false,
        positional=true,
        required=true,
        has_default=false,
    ),
    SYM_POS_DEF => (
        kind=AK_POS_DEFAULT,
        macro_name="@POS_DEF",
        type_idx=3,
        default_idx=4,
        name_idx=5,
        require_flags=false,
        positional=true,
        required=false,
        has_default=true,
    ),
    SYM_POS_OPT => (
        kind=AK_POS_OPTIONAL,
        macro_name="@POS_OPT",
        type_idx=3,
        default_idx=nothing,
        name_idx=4,
        require_flags=false,
        positional=true,
        required=false,
        has_default=false,
    ),
    SYM_POS_RST => (
        kind=AK_POS_REST,
        macro_name="@POS_REST",
        type_idx=3,
        default_idx=nothing,
        name_idx=4,
        require_flags=false,
        positional=true,
        required=false,
        has_default=false,
    ),
)

function _parse_schema_arg(node::Expr, schema)::NormalizedArgSpec
    T = schema.type_idx === nothing ? (schema.kind == AK_FLAG ? Bool : schema.kind == AK_COUNT ? Int : Any) : node.args[schema.type_idx]
    dv = schema.default_idx === nothing ? nothing : node.args[schema.default_idx]
    nm, rest = _extract_name_and_rest(node, schema.name_idx, schema.macro_name, "argument name")
    help, help_name = _extract_help_meta!(rest; allow_help_name=true, macro_name=schema.macro_name)

    flags = if schema.require_flags
        fs = _extract_flags!(rest, schema.macro_name)
        isempty(fs) && throw(ArgumentError("$(schema.macro_name) requires at least one flag"))
        fs
    else
        isempty(rest) || throw(ArgumentError("$(schema.macro_name) supports only keyword metadata: help=\"...\", help_name=\"...\""))
        String[]
    end

    return NormalizedArgSpec(
        kind=schema.kind,
        name=nm,
        T=T,
        flags=flags,
        default=dv,
        help=help,
        help_name=help_name,
        required=schema.required
    )
end

function _replace_arg_spec!(spec::NormalizedCmdSpec, arg_by_name::Dict{Symbol,NormalizedArgSpec}, nm::Symbol, mode::Symbol, fn, msg::String)
    haskey(arg_by_name, nm) || throw(ArgumentError("$(mode == :test ? "@ARG_TEST" : "@ARG_STREAM") references unknown argument: $(nm)"))

    old = arg_by_name[nm]
    new = NormalizedArgSpec(
        kind=old.kind,
        name=old.name,
        T=old.T,
        flags=old.flags,
        default=old.default,
        help=old.help,
        help_name=old.help_name,
        required=old.required,
        validator=fn,
        validator_message=msg,
        validator_mode=mode
    )

    idx = findfirst(a -> a.name == nm, spec.args)
    spec.args[idx] = new
    arg_by_name[nm] = new
    return nothing
end

function _parse_cmd_block_spec(block::Expr)::NormalizedCmdSpec
    spec = NormalizedCmdSpec()
    arg_by_name = Dict{Symbol,NormalizedArgSpec}()

    for node in _getmacrocalls(block)
        m = _getmacroname(node)
        m === nothing && throw(ArgumentError("unsupported DSL macro expression"))

        if haskey(_ARG_SCHEMA, m)
            arg = _parse_schema_arg(node, _ARG_SCHEMA[m])
            push!(spec.args, arg)
            arg_by_name[arg.name] = arg

        elseif m == SYM_GROUP
            syms = [_expect_name_symbol(node.args[i], "@GROUP_EXCL", "argument name") for i in 3:length(node.args)]
            push!(spec.mutual_exclusion_groups, syms)

        elseif m == SYM_GROUP_INCL
            syms = [_expect_name_symbol(node.args[i], "@GROUP_INCL", "argument name") for i in 3:length(node.args)]
            push!(spec.mutual_inclusion_groups, syms)

        elseif m == SYM_ARG_REQUIRES
            anchor = _expect_name_symbol(node.args[3], "@ARG_REQUIRES", "anchor argument")
            targets = [_expect_name_symbol(node.args[i], "@ARG_REQUIRES", "target argument") for i in 4:length(node.args)]
            push!(spec.arg_requires, ArgRequiresDef(anchor=anchor, targets=targets))

        elseif m == SYM_ARG_CONFLICTS
            anchor = _expect_name_symbol(node.args[3], "@ARG_CONFLICTS", "anchor argument")
            targets = [_expect_name_symbol(node.args[i], "@ARG_CONFLICTS", "target argument") for i in 4:length(node.args)]
            push!(spec.arg_conflicts, ArgConflictsDef(anchor=anchor, targets=targets))

        elseif m == SYM_TEST
            nm, rest = _extract_name_and_rest(node, 3, "@ARG_TEST", "argument name")
            isempty(rest) && throw(ArgumentError("@ARG_TEST requires a validator function"))
            fn = rest[1]
            msg = if length(rest) >= 2
                rest[2] isa String || throw(ArgumentError("@ARG_TEST message must be a String literal"))
                rest[2]
            else
                "Argument test failed: $(nm)"
            end
            length(rest) <= 2 || throw(ArgumentError("@ARG_TEST accepts at most one message String"))
            _replace_arg_spec!(spec, arg_by_name, nm, :test, fn, msg)

        elseif m == SYM_STREAM
            nm, rest = _extract_name_and_rest(node, 3, "@ARG_STREAM", "argument name")
            isempty(rest) && throw(ArgumentError("@ARG_STREAM requires a validator function"))
            fn = rest[1]
            msg = if length(rest) >= 2
                rest[2] isa String || throw(ArgumentError("@ARG_STREAM message must be a String literal"))
                rest[2]
            else
                "Streaming validation failed: $(nm)"
            end
            length(rest) <= 2 || throw(ArgumentError("@ARG_STREAM accepts at most one message String"))
            _replace_arg_spec!(spec, arg_by_name, nm, :stream, fn, msg)

        elseif m in (SYM_USAGE, SYM_DESC, SYM_EPILOG, SYM_SUB, SYM_ALLOW)
        else
            throw(ArgumentError("unsupported DSL macro: $(m)"))
        end
    end

    _validate_cmd_spec!(spec)
    return spec
end

function _emit_argdef_expr(a::NormalizedArgSpec)
    kind_expr = :($(_gr(Symbol(string(a.kind)))))
    pairs = Any[
        :(kind = $kind_expr),
        :(name = $(QuoteNode(a.name))),
        :(T = $(a.T)),
        :(help = $(a.help)),
        :(help_name = $(a.help_name)),
    ]

    if _is_option_kind(a.kind)
        push!(pairs, :(flags = $(a.flags)))
    end

    if a.default !== nothing
        push!(pairs, :(default = $(a.default)))
    end

    if a.required
        push!(pairs, :(required = true))
    end

    return Expr(:call, :($(_gr(:ArgDef))), Expr(:parameters, pairs...))
end

function _emit_arg_field(a::NormalizedArgSpec)
    nm = a.name
    T = a.T

    field_type = if _is_flag_kind(a.kind)
        :Bool
    elseif _is_count_kind(a.kind)
        :Int
    elseif _is_option_multi_kind(a.kind) || _is_pos_rest_kind(a.kind)
        :(Vector{$(T)})
    elseif _is_option_scalar_kind(a.kind)
        (a.required || a.default !== nothing) ? T : :(Union{$(T),Nothing})
    elseif _is_pos_required_kind(a.kind) || _is_pos_default_kind(a.kind)
        T
    elseif _is_pos_optional_kind(a.kind)
        :(Union{$(T),Nothing})
    else
        error("unsupported arg kind")
    end

    return :($(nm)::$(field_type))
end

function _emit_option_like_parse_stmt(a::NormalizedArgSpec)
    nm = a.name
    T = a.T
    provided_sym = Symbol("_provided_", nm)

    if _is_option_scalar_kind(a.kind)
        tmp_sym = Symbol("_tmp_", nm)
        raw_sym = Symbol("_raw_", nm)

        value_expr = if a.required
            quote
                isnothing($(raw_sym)) && $(_gr(:_throw_arg_error))("Missing required option $( $(a.flags[end]) )")
                $(_gr(:_parse_value))($(T), $(raw_sym), $(string(nm)))
            end
        elseif a.default !== nothing
            quote
                isnothing($(raw_sym)) ? $(_gr(:_convert_default))($(T), $(a.default), $(string(nm))) :
                                        $(_gr(:_parse_value))($(T), $(raw_sym), $(string(nm)))
            end
        else
            quote
                isnothing($(raw_sym)) ? nothing :
                                        $(_gr(:_parse_value))($(T), $(raw_sym), $(string(nm)))
            end
        end

        return quote
            $(tmp_sym) = $(_gr(:_pop_value_once!))(_opt_args, $(a.flags), $(string(nm)), allow_empty_option_value)
            $(raw_sym) = $(tmp_sym)[1]
            $(provided_sym) = $(tmp_sym)[2]
            $(nm) = $(value_expr)
        end

    elseif _is_flag_kind(a.kind)
        flag_before_sym = Symbol("_flag_before_", nm)
        return quote
            $(flag_before_sym) = length(_opt_args)
            $(nm) = $(_gr(:_pop_flag!))(_opt_args, $(a.flags))
            $(provided_sym) = ($(flag_before_sym) != length(_opt_args))
        end

    elseif _is_count_kind(a.kind)
        cnt_sym = Symbol("_cnt_", nm)
        count_stmts = [:( $(cnt_sym) += $(_gr(:_pop_count!))(_opt_args, $(f)) ) for f in a.flags]
        return quote
            $(cnt_sym) = 0
            $(count_stmts...)
            $(nm) = $(cnt_sym)
            $(provided_sym) = ($(nm) > 0)
        end

    elseif _is_option_multi_kind(a.kind)
        vals_sym = Symbol("_vals_", nm)
        return quote
            $(vals_sym) = $(_gr(:_pop_multi_values!))(_opt_args, $(a.flags), allow_empty_option_value)
            $(provided_sym) = !isempty($(vals_sym))
            $(nm) = [ $(_gr(:_parse_value))($(T), v, $(string(nm))) for v in $(vals_sym) ]
        end
    else
        return nothing
    end
end

function _emit_positional_like_parse_stmt(a::NormalizedArgSpec)
    nm = a.name
    T = a.T
    provided_sym = Symbol("_provided_", nm)

    if _is_pos_required_kind(a.kind)
        return quote
            isempty(_args) && $(_gr(:_throw_arg_error))("Missing required positional $( $(string(nm)) )")
            $(provided_sym) = true
            $(nm) = $(_gr(:_parse_value))($(T), popfirst!(_args), $(string(nm)))
        end

    elseif _is_pos_default_kind(a.kind)
        return quote
            $(provided_sym) = !isempty(_args)
            $(nm) = isempty(_args) ? $(_gr(:_convert_default))($(T), $(a.default), $(string(nm))) :
                                     $(_gr(:_parse_value))($(T), popfirst!(_args), $(string(nm)))
        end

    elseif _is_pos_optional_kind(a.kind)
        return quote
            $(provided_sym) = !isempty(_args)
            $(nm) = isempty(_args) ? nothing :
                                     $(_gr(:_parse_value))($(T), popfirst!(_args), $(string(nm)))
        end

    elseif _is_pos_rest_kind(a.kind)
        return quote
            $(provided_sym) = !isempty(_args)
            $(nm) = [ $(_gr(:_parse_value))($(T), x, $(string(nm))) for x in _args ]
            empty!(_args)
        end
    else
        return nothing
    end
end

function _emit_validator_stmt(a::NormalizedArgSpec)
    nm = a.name
    if a.validator_mode == :none || a.validator === nothing
        return nothing
    elseif a.validator_mode == :test
        fn = a.validator
        msg = a.validator_message
        return quote
            if !(isnothing($(nm)) || $(fn)($(nm)))
                local _vname = try String(nameof($(fn))) catch; "validator" end
                $(_gr(:_throw_arg_error))($(msg) * " (arg=$(string($(QuoteNode(nm)))), validator=" * _vname * ", value=" * repr($(nm)) * ")")
            end
        end
    elseif a.validator_mode == :stream
        fn = a.validator
        msg = a.validator_message
        return quote
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
        end
    else
        error("unsupported validator mode")
    end
end

function _emit_cmd_block(spec::NormalizedCmdSpec)
    fields = Expr[]
    option_parse_stmts = Expr[]
    positional_parse_stmts = Expr[]
    post_stmts = Expr[]
    argdefs_expr = Expr[]

    for a in spec.args
        push!(fields, _emit_arg_field(a))

        opt_stmt = _emit_option_like_parse_stmt(a)
        opt_stmt === nothing || push!(option_parse_stmts, opt_stmt)

        pos_stmt = _emit_positional_like_parse_stmt(a)
        pos_stmt === nothing || push!(positional_parse_stmts, pos_stmt)

        val_stmt = _emit_validator_stmt(a)
        val_stmt === nothing || push!(post_stmts, val_stmt)

        push!(argdefs_expr, _emit_argdef_expr(a))
    end

    return (
        fields,
        option_parse_stmts,
        positional_parse_stmts,
        post_stmts,
        argdefs_expr,
        spec.mutual_exclusion_groups,
        spec.mutual_inclusion_groups,
        spec.arg_requires,
        spec.arg_conflicts
    )
end

function _compile_cmd_block(block::Expr)
    spec = _parse_cmd_block_spec(block)
    return _emit_cmd_block(spec)
end
