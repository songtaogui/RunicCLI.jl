
@inline function _build_subcommand_help_branch(sub_name, local_sub_def_expr)
    quote
        if _sub == $(sub_name)
            local _sub_def = $(local_sub_def_expr)
            throw($(_gr(:ArgHelpRequested))(_sub_def, _path * " " * $(sub_name)))
        end
    end
end

function _build_subcommand_bundle(normalized_sub_nodes::Vector{NormalizedSubCmd}, struct_name, main_ctor_args::Vector{Symbol})
    sub_def_items = Expr[]
    sub_parser_exprs = Expr[]
    dispatch_branches = Expr[]
    sub_help_branches = Expr[]
    sub_version_branches = Expr[]
    sub_names = String[]

    for sn in normalized_sub_nodes
        sub_name, sub_desc, sub_usage, sub_epilog, sub_version = sn.name, sn.description, sn.usage, sn.epilog, sn.version
        sub_block, sub_allow_extra = sn.block, sn.allow_extra
        push!(sub_names, sub_name)

        sub_main_nodes = Expr[]
        for n in _getmacrocalls(sub_block)
            mm = _getmacroname(n)
            if mm in (SYM_DESC, SYM_USAGE, SYM_EPILOG, SYM_VERSION, SYM_ALLOW)
                continue
            end
            push!(sub_main_nodes, n)
        end
        sub_main_block = Expr(:block, sub_main_nodes...)

        s_fields, s_option_parse_stmts, s_positional_parse_stmts, s_post_stmts, s_argdefs_expr,
        s_gdefs_excl, s_gdefs_incl, s_arg_requires_defs, s_arg_conflicts_defs = _compile_cmd_block(sub_main_block)

        s_ctor_args = Symbol[f.args[1] for f in s_fields]
        s_parser_name = gensym(Symbol("parse_sub_", replace(sub_name, r"[^A-Za-z0-9_]" => "_")))
        s_nt_expr = :( (; $(s_ctor_args...)) )

        push!(sub_parser_exprs, _emit_parser_function(
            s_parser_name, :($s_nt_expr), s_fields, s_ctor_args,
            s_option_parse_stmts, s_positional_parse_stmts, s_post_stmts,
            s_gdefs_excl, s_gdefs_incl, s_arg_requires_defs, s_arg_conflicts_defs, sub_allow_extra
        ))

        main_field_exprs = [:(getfield(_main_obj, $(QuoteNode(nm)))) for nm in main_ctor_args]

        push!(dispatch_branches, quote
            if _sub == $(sub_name)
                local _payload = $(s_parser_name)(_rest)
                return $(struct_name)($(main_field_exprs...), _sub, _payload)
            end
        end)

        local_sub_def_expr = _build_clidef_expr(
            sub_name, sub_usage, sub_desc, sub_epilog, sub_version,
            :($(_gr(:ArgDef))[$(s_argdefs_expr...)]),
            :($(_gr(:SubcommandDef))[]),
            sub_allow_extra, s_gdefs_excl, s_gdefs_incl, s_arg_requires_defs, s_arg_conflicts_defs
        )

        push!(sub_help_branches, _build_subcommand_help_branch(sub_name, local_sub_def_expr))

        push!(sub_version_branches, quote
            if _sub == $(sub_name)
                local _sv = get(_cfg, _sub * ".version", nothing)
                local _vmsg = _sv === nothing ? $(sub_version) : String(_sv)
                throw($(_gr(:ArgHelpRequested))(_vmsg))
            end
        end)

        push!(sub_def_items, _build_subcommand_def_expr(
            sub_name, sub_desc, sub_usage, sub_epilog, sub_version,
            s_argdefs_expr, sub_allow_extra,
            s_gdefs_excl, s_gdefs_incl, s_arg_requires_defs, s_arg_conflicts_defs
        ))
    end

    return sub_def_items, sub_parser_exprs, dispatch_branches, sub_help_branches, sub_version_branches, sub_names
end
