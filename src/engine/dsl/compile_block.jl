
function _handle_group_excl!(ctx::_CompileCtx, node::Expr)
    length(node.args) >= 4 || throw(ArgumentError("@GROUP_EXCL requires at least 2 argument names"))
    syms = _collect_symbol_args(node, 3, "@GROUP_EXCL", "argument name")
    _ensure_min_count!(syms, 2, "@GROUP_EXCL", "argument names")
    _ensure_no_duplicates!(syms, "@GROUP_EXCL", "argument names")
    push!(ctx.group_defs_excl, syms)
end

function _handle_group_incl!(ctx::_CompileCtx, node::Expr)
    length(node.args) >= 4 || throw(ArgumentError("@GROUP_INCL requires at least 2 argument names"))
    syms = _collect_symbol_args(node, 3, "@GROUP_INCL", "argument name")
    _ensure_min_count!(syms, 2, "@GROUP_INCL", "argument names")
    _ensure_no_duplicates!(syms, "@GROUP_INCL", "argument names")
    push!(ctx.group_defs_incl, syms)
end

function _handle_arg_requires!(ctx::_CompileCtx, node::Expr)
    length(node.args) >= 4 || throw(ArgumentError("@ARG_REQUIRES requires an anchor argument and at least one target argument"))
    anchor = _expect_name_symbol(node.args[3], "@ARG_REQUIRES", "anchor argument")
    targets = _collect_symbol_args(node, 4, "@ARG_REQUIRES", "target argument")
    _ensure_min_count!(targets, 1, "@ARG_REQUIRES", "target arguments")
    anchor in targets && throw(ArgumentError("@ARG_REQUIRES anchor argument must not appear in targets"))
    _ensure_no_duplicates!(targets, "@ARG_REQUIRES", "target arguments")
    push!(ctx.arg_requires_defs, ArgRequiresDef(anchor=anchor, targets=targets))
end

function _handle_arg_conflicts!(ctx::_CompileCtx, node::Expr)
    length(node.args) >= 4 || throw(ArgumentError("@ARG_CONFLICTS requires an anchor argument and at least one target argument"))
    anchor = _expect_name_symbol(node.args[3], "@ARG_CONFLICTS", "anchor argument")
    targets = _collect_symbol_args(node, 4, "@ARG_CONFLICTS", "target argument")
    _ensure_min_count!(targets, 1, "@ARG_CONFLICTS", "target arguments")
    anchor in targets && throw(ArgumentError("@ARG_CONFLICTS anchor argument must not appear in targets"))
    _ensure_no_duplicates!(targets, "@ARG_CONFLICTS", "target arguments")
    push!(ctx.arg_conflicts_defs, ArgConflictsDef(anchor=anchor, targets=targets))
end

function _handle_arg_test!(ctx::_CompileCtx, node::Expr)
    length(node.args) >= 4 || throw(ArgumentError("@ARG_TEST requires an argument name and a validator function"))
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
end

const _COMPILE_BLOCK_HANDLERS = Dict{Symbol,Function}(
    SYM_GROUP => _handle_group_excl!,
    SYM_GROUP_INCL => _handle_group_incl!,
    SYM_ARG_REQUIRES => _handle_arg_requires!,
    SYM_ARG_CONFLICTS => _handle_arg_conflicts!,
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
           ctx.group_defs_excl,
           ctx.group_defs_incl,
           ctx.arg_requires_defs,
           ctx.arg_conflicts_defs
end

