function _extract_rel_help!(args::Vector{Any}, macro_name::String)
    help = ""
    kept = Any[]

    for x in args
        if x isa Expr && x.head == :(=) && length(x.args) == 2 && x.args[1] == :help
            isempty(help) || throw(ArgumentError("$(macro_name) accepts at most one help=... keyword"))
            x.args[2] isa String || throw(ArgumentError("$(macro_name) help must be a String literal"))
            help = x.args[2]
        else
            push!(kept, x)
        end
    end

    return kept, help
end

function _expect_rel_member_symbol(x, macro_name::String)
    if x isa Symbol
        return x
    elseif x isa QuoteNode && x.value isa Symbol
        return x.value
    else
        throw(ArgumentError("$(macro_name) expects argument names as Symbols"))
    end
end

function _parse_relation_expr(x, macro_name::String)::RelationExpr
    if x isa Symbol
        return RelAll(members=[x])
    elseif x isa QuoteNode && x.value isa Symbol
        return RelAll(members=[x.value])
    elseif x isa Expr && x.head == :call && !isempty(x.args)
        fn = x.args[1]

        if fn == :all
            length(x.args) >= 2 || throw(ArgumentError("$(macro_name) all(...) requires at least one argument name"))
            members = [_expect_rel_member_symbol(a, macro_name) for a in x.args[2:end]]
            _ensure_no_duplicates!(members, macro_name, "all(...) members")
            return RelAll(members=members)

        elseif fn == :any
            length(x.args) >= 2 || throw(ArgumentError("$(macro_name) any(...) requires at least one argument name"))
            members = [_expect_rel_member_symbol(a, macro_name) for a in x.args[2:end]]
            _ensure_no_duplicates!(members, macro_name, "any(...) members")
            return RelAny(members=members)

        elseif fn == :not
            length(x.args) == 2 || throw(ArgumentError("$(macro_name) not(...) requires exactly one inner expression"))
            return RelNot(inner=_parse_relation_expr(x.args[2], macro_name))
        end
    end

    throw(ArgumentError(
        "$(macro_name) expects a relation expression like a, all(a, b), any(a, b), or not(any(a, b))"
    ))
end

function _collect_relation_members!(out::Set{Symbol}, expr::RelationExpr)
    if expr isa RelAll
        foreach(s -> push!(out, s), expr.members)
    elseif expr isa RelAny
        foreach(s -> push!(out, s), expr.members)
    elseif expr isa RelNot
        _collect_relation_members!(out, expr.inner)
    else
        throw(ArgumentError("internal error: unsupported RelationExpr"))
    end
end

function _handle_argrel_depends!(ctx::_CompileCtx, node::Expr)
    raw = Any[node.args[i] for i in 3:length(node.args)]
    raw, help = _extract_rel_help!(raw, "@ARGREL_DEPENDS")
    length(raw) == 2 || throw(ArgumentError("@ARGREL_DEPENDS expects exactly two relation expressions"))

    lhs = _parse_relation_expr(raw[1], "@ARGREL_DEPENDS")
    rhs = _parse_relation_expr(raw[2], "@ARGREL_DEPENDS")

    push!(ctx.relation_defs, ArgRelationDef(
        kind=:depends,
        lhs=lhs,
        rhs=rhs,
        help=help
    ))
end

function _handle_argrel_conflicts!(ctx::_CompileCtx, node::Expr)
    raw = Any[node.args[i] for i in 3:length(node.args)]
    raw, help = _extract_rel_help!(raw, "@ARGREL_CONFLICTS")
    length(raw) == 2 || throw(ArgumentError("@ARGREL_CONFLICTS expects exactly two relation expressions"))

    lhs = _parse_relation_expr(raw[1], "@ARGREL_CONFLICTS")
    rhs = _parse_relation_expr(raw[2], "@ARGREL_CONFLICTS")

    push!(ctx.relation_defs, ArgRelationDef(
        kind=:conflicts,
        lhs=lhs,
        rhs=rhs,
        help=help
    ))
end

function _handle_argrel_group_kind!(ctx::_CompileCtx, node::Expr, macro_name::String, kind::Symbol)
    raw = Any[node.args[i] for i in 3:length(node.args)]
    raw, help = _extract_rel_help!(raw, macro_name)

    !isempty(raw) || throw(ArgumentError("$(macro_name) requires at least one argument name"))
    members = [_expect_rel_member_symbol(x, macro_name) for x in raw]
    _ensure_no_duplicates!(members, macro_name, "argument names")

    push!(ctx.relation_defs, ArgRelationDef(
        kind=kind,
        members=members,
        help=help
    ))
end

function _handle_argrel_atmostone!(ctx::_CompileCtx, node::Expr)
    _handle_argrel_group_kind!(ctx, node, "@ARGREL_ATMOSTONE", :atmostone)
end

function _handle_argrel_atleastone!(ctx::_CompileCtx, node::Expr)
    _handle_argrel_group_kind!(ctx, node, "@ARGREL_ATLEASTONE", :atleastone)
end

function _handle_argrel_onlyone!(ctx::_CompileCtx, node::Expr)
    _handle_argrel_group_kind!(ctx, node, "@ARGREL_ONLYONE", :onlyone)
end

function _handle_argrel_allornone!(ctx::_CompileCtx, node::Expr)
    _handle_argrel_group_kind!(ctx, node, "@ARGREL_ALLORNONE", :allornone)
end

function _handle_arg_group!(ctx::_CompileCtx, node::Expr)
    length(node.args) >= 4 || throw(ArgumentError("@ARG_GROUP requires a title String and at least one argument name"))

    title = node.args[3]
    title isa String || throw(ArgumentError("@ARG_GROUP title must be a String literal"))
    isempty(strip(title)) && throw(ArgumentError("@ARG_GROUP title must not be empty"))

    members = _collect_symbol_args(node, 4, "@ARG_GROUP", "argument name")
    _ensure_min_count!(members, 1, "@ARG_GROUP", "argument names")
    _ensure_no_duplicates!(members, "@ARG_GROUP", "argument names")

    push!(ctx.arg_group_defs, ArgGroupDef(title=title, members=members))
end

function _handle_arg_test!(ctx::_CompileCtx, node::Expr)
    length(node.args) >= 5 || throw(ArgumentError("@ARG_TEST requires at least one argument name, a validator function, and optional message"))

    raw = Any[node.args[i] for i in 3:length(node.args)]
    fn_idx = findfirst(x -> !(x isa Symbol || (x isa QuoteNode && x.value isa Symbol)), raw)
    fn_idx === nothing && throw(ArgumentError("@ARG_TEST requires a validator function"))

    fn_idx >= 2 || throw(ArgumentError("@ARG_TEST requires at least one argument name before validator function"))

    nms = Symbol[]
    for i in 1:(fn_idx - 1)
        nm = _expect_name_symbol(raw[i], "@ARG_TEST", "argument name")
        nm in ctx.declared_names || throw(ArgumentError("@ARG_TEST references unknown argument: $(nm)"))
        push!(nms, nm)
    end
    _ensure_no_duplicates!(nms, "@ARG_TEST", "argument names")

    fn = raw[fn_idx]
    rest = raw[(fn_idx + 1):end]

    msg = if isempty(rest)
        nothing
    elseif length(rest) == 1
        rest[1] isa String || throw(ArgumentError("@ARG_TEST message must be a String literal"))
        rest[1]
    else
        throw(ArgumentError("@ARG_TEST accepts at most one message String"))
    end

    for nm in nms
        push!(ctx.post_stmts, quote
            local _vs = $(_gr(:validator))($(fn))
            local _vfn = $(_gr(:validator_fn))(_vs)
            local _vmsg = $(msg === nothing ? :(nothing) : msg)
            local _final_msg = $(_gr(:validator_resolve_message))(_vs, _vmsg, "Argument test failed")
            if !(isnothing($(nm)) || _vfn($(nm)))
                local _vname = $(_gr(:validator_name))(_vfn)
                $(_gr(:_throw_arg_error))("Invalid arg: " * $(string(nm)) * " => " * _final_msg * "\n (validator=" * _vname * ", value=" * repr($(nm)) * ")")
            end
        end)
    end
end

function _handle_arg_stream!(ctx::_CompileCtx, node::Expr)
    length(node.args) >= 4 || throw(ArgumentError("@ARG_STREAM requires an argument name and a validator function"))
    nm, rest = _extract_name_and_rest(node, 3, "@ARG_STREAM", "argument name")
    nm in ctx.declared_names || throw(ArgumentError("@ARG_STREAM references unknown argument: $(nm)"))
    isempty(rest) && throw(ArgumentError("@ARG_STREAM requires a validator function"))

    fn = rest[1]
    msg = if length(rest) >= 2
        rest[2] isa String || throw(ArgumentError("@ARG_STREAM message must be a String literal"))
        rest[2]
    else
        nothing
    end
    length(rest) <= 2 || throw(ArgumentError("@ARG_STREAM accepts at most one message String"))

    push!(ctx.post_stmts, quote
        local _vs = $(_gr(:validator))($(fn))
        local _vfn = $(_gr(:validator_fn))(_vs)
        local _vname = $(_gr(:validator_name))(_vfn)
        local _final_msg = $(_gr(:validator_resolve_message))(_vs, $(msg === nothing ? :(nothing) : msg), "Streaming validation failed")
        local _fails = String[]
        if $(nm) isa AbstractVector
            for _v in $(nm)
                if !_vfn(_v)
                    push!(_fails, repr(_v))
                end
            end
        elseif !(isnothing($(nm)) || _vfn($(nm)))
            push!(_fails, repr($(nm)))
        end
        if !isempty(_fails)
            $(_gr(:_throw_arg_error))("Invalid arg: " * $(string(nm)) * " => " * _final_msg * "\n (validator=" * _vname * ", failed_values=[" * join(_fails, ", ") * "])")
        end
    end)
end

const _COMPILE_BLOCK_HANDLERS = Dict{Symbol,Function}(
    SYM_ARGREL_DEPENDS => _handle_argrel_depends!,
    SYM_ARGREL_CONFLICTS => _handle_argrel_conflicts!,
    SYM_ARGREL_ATMOSTONE => _handle_argrel_atmostone!,
    SYM_ARGREL_ATLEASTONE => _handle_argrel_atleastone!,
    SYM_ARGREL_ONLYONE => _handle_argrel_onlyone!,
    SYM_ARGREL_ALLORNONE => _handle_argrel_allornone!,
    SYM_ARG_GROUP => _handle_arg_group!,
    SYM_TEST => _handle_arg_test!,
    SYM_STREAM => _handle_arg_stream!,
)

function _compile_cmd_block(block::Expr)
    ctx = _CompileCtx()

    for node in _getmacrocalls(block)
        m = _getmacroname(node)
        m === nothing && throw(ArgumentError("unsupported DSL macro expression"))

        if haskey(_ARG_DECL_SPECS, m)
            decl = _parse_decl_pipeline!(ctx, _ARG_DECL_SPECS[m], node)
            _emit_decl_codegen!(ctx, decl)
            continue
        end

        handler = get(_COMPILE_BLOCK_HANDLERS, m, nothing)
        handler === nothing && throw(ArgumentError("unsupported DSL macro: $(m)"))
        handler(ctx, node)
    end

    _validate_relations!(ctx)

    return ctx.fields,
           ctx.option_parse_stmts,
           ctx.positional_parse_stmts,
           ctx.post_stmts,
           ctx.argdefs_expr,
           ctx.relation_defs,
           ctx.arg_group_defs
end
