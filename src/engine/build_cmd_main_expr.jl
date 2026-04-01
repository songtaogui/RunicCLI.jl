function build_cmd_main_expr(struct_name, block)
    if !(block isa Expr && block.head == :block)
        throw(ArgumentError("@CMD_MAIN expects a `begin ... end` block as second argument"))
    end

    if !(struct_name isa Symbol)
        throw(ArgumentError("@CMD_MAIN first argument must be a plain type name Symbol (e.g. MyType), dotted names are not supported"))
    end

    nonmacro = _nonmacro_nodes(block)
    if !isempty(nonmacro)
        throw(ArgumentError("Only DSL macros are allowed inside @CMD_MAIN block; found non-macro statement(s)"))
    end

    main_meta = _parse_cmd_meta_block(
        block;
        initial_desc="",
        desc_predeclared=false,
        dup_ctx="@CMD_MAIN",
        expect_ctx=""
    )

    usage = main_meta.usage
    desc = main_meta.desc
    epilog = main_meta.epilog
    version = main_meta.version
    allow_extra = main_meta.allow_extra

    main_nodes = Expr[]
    normalized_sub_nodes = NormalizedSubCmd[]

    for node in main_meta.other_nodes
        m = _getmacroname(node)

        if m == SYM_SUB
            sub_name, sub_desc, sub_block = _parse_sub_signature(node)

            nonmacro_sub = _nonmacro_nodes(sub_block)
            if !isempty(nonmacro_sub)
                throw(ArgumentError("Only DSL macros are allowed inside @CMD_SUB block; found non-macro statement(s)"))
            end

            sub_meta = _parse_cmd_meta_block(
                sub_block;
                initial_desc=sub_desc,
                desc_predeclared=!isempty(sub_desc),
                dup_ctx="@CMD_SUB \"$(sub_name)\"",
                expect_ctx="@CMD_SUB \"$(sub_name)\""
            )

            if any(s.name == sub_name for s in normalized_sub_nodes)
                throw(ArgumentError("duplicate subcommand name: $(sub_name)"))
            end

            push!(normalized_sub_nodes, NormalizedSubCmd(
                name=sub_name,
                description=sub_meta.desc,
                usage=sub_meta.usage,
                epilog=sub_meta.epilog,
                version=sub_meta.version,
                block=Expr(:block, sub_meta.other_nodes...),
                allow_extra=sub_meta.allow_extra
            ))
        else
            push!(main_nodes, node)
        end
    end

    main_block = Expr(:block, main_nodes...)
    fields, option_parse_stmts, positional_parse_stmts, post_stmts, argdefs_expr, gdefs_excl, gdefs_incl, arg_requires_defs, arg_conflicts_defs, arg_group_defs =
        _compile_cmd_block(main_block)

    ctor_args = Symbol[f.args[1] for f in fields]

    sub_def_items, sub_parser_exprs, dispatch_branches, sub_help_branches, sub_version_branches, sub_names =
        _build_subcommand_bundle(normalized_sub_nodes, struct_name, ctor_args)

    return _build_main_parser_expr(
        struct_name, usage, desc, epilog, version, allow_extra,
        fields, ctor_args, option_parse_stmts, positional_parse_stmts, post_stmts, argdefs_expr,
        gdefs_excl, gdefs_incl, arg_requires_defs, arg_conflicts_defs, arg_group_defs,
        sub_def_items, sub_parser_exprs, dispatch_branches, sub_help_branches, sub_version_branches, sub_names
    )
end
