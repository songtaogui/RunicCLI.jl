# RunicCLI
# macros/subcommands.jl

Base.@kwdef struct NormalizedSubCmd
    name::String
    description::String = ""
    usage::String = ""
    epilog::String = ""
    block::Expr
    allow_extra::Bool = false
end

"""
Build subcommand metadata and dispatch branches from normalized @CMD_SUB nodes.

Input nodes are expected in normalized form:
Expr(:macrocall, ..., sub_name::String, sub_desc::String, sub_block::Expr, sub_allow_extra::Bool)
"""
function _build_subcommand_bundle(normalized_sub_nodes::Vector{NormalizedSubCmd}, struct_name, main_ctor_args::Vector{Symbol})
    sub_def_items = Expr[]
    sub_parser_exprs = Expr[]
    dispatch_branches = Expr[]
    sub_help_branches = Expr[]
    sub_names = String[]

    for sn in normalized_sub_nodes
        sub_name = sn.name
        sub_desc = sn.description
        sub_usage = sn.usage
        sub_epilog = sn.epilog
        sub_block = sn.block
        sub_allow_extra = sn.allow_extra

        push!(sub_names, sub_name)

        sub_main_nodes = Expr[]
        for n in _getmacrocalls(sub_block)
            mm = _getmacroname(n)
            if mm in (SYM_DESC, SYM_USAGE, SYM_EPILOG, SYM_ALLOW)
                continue
            end
            push!(sub_main_nodes, n)
        end
        sub_main_block = Expr(:block, sub_main_nodes...)

        sub_spec = _parse_cmd_block_spec(sub_main_block)

        s_fields, s_option_parse_stmts, s_positional_parse_stmts, s_post_stmts, s_argdefs_expr,
        s_gdefs_excl, s_gdefs_incl, s_arg_requires_defs, s_arg_conflicts_defs = _emit_cmd_block(sub_spec)

        s_ctor_args = Symbol[a.name for a in sub_spec.args]

        s_parser_name = gensym(Symbol("parse_sub_", replace(sub_name, r"[^A-Za-z0-9_]" => "_")))
        s_nt_expr = _emit_namedtuple_literal(s_ctor_args)

        s_parser_expr = _emit_parser_function(
            s_parser_name,
            s_nt_expr,
            s_ctor_args,
            s_option_parse_stmts,
            s_positional_parse_stmts,
            s_post_stmts,
            s_gdefs_excl,
            s_gdefs_incl,
            s_arg_requires_defs,
            s_arg_conflicts_defs,
            sub_allow_extra
        )

        main_field_exprs = [:(getfield(_main_obj, $(QuoteNode(nm)))) for nm in main_ctor_args]

        s_excl_expr, s_incl_expr, s_arg_requires_expr, s_arg_conflicts_expr = _emit_constraint_exprs(sub_spec)
        s_args_expr = :($(_gr(:ArgDef))[$(s_argdefs_expr...)])

        s_common_kwargs = _emit_cli_common_kwargs_expr(
            sub_usage,
            sub_desc,
            sub_epilog,
            s_args_expr,
            sub_allow_extra,
            s_excl_expr,
            s_incl_expr,
            s_arg_requires_expr,
            s_arg_conflicts_expr
        )

        push!(dispatch_branches, quote
            if _sub == $(sub_name)
                local _payload = $(s_parser_name)(_rest)
                return $(struct_name)($(main_field_exprs...), _sub, _payload)
            end
        end)

        push!(sub_help_branches, quote
            if _sub == $(sub_name)
                local _sub_def = $(_gr(:CliDef))(
                    cmd_name = $(sub_name),
                    $(s_common_kwargs),
                    subcommands = $(_gr(:SubcommandDef))[]
                )
                throw($(_gr(:ArgHelpRequested))(_sub_def, _path * " " * $(sub_name)))
            end
        end)

        push!(sub_def_items, :($(_gr(:SubcommandDef))(
            name = $(sub_name),
            $(s_common_kwargs),
            body = nothing
        )))

        push!(sub_parser_exprs, s_parser_expr)
    end

    return sub_def_items, sub_parser_exprs, dispatch_branches, sub_help_branches, sub_names
end


"""
Build final expansion for @CMD_MAIN.
"""
function _build_main_parser_expr(
    struct_name, usage, desc, epilog, allow_extra,
    fields, ctor_args, option_parse_stmts, positional_parse_stmts, post_stmts, argdefs_expr,
    gdefs_excl, gdefs_incl, arg_requires_defs, arg_conflicts_defs,
    sub_def_items, sub_parser_exprs, dispatch_branches, sub_help_branches, sub_names
)
    main_parser_name = gensym(:parse_main)
    main_result_expr = _emit_namedtuple_literal(ctor_args)

    main_spec = NormalizedCmdSpec(
        args=NormalizedArgSpec[],
        mutual_exclusion_groups=gdefs_excl,
        mutual_inclusion_groups=gdefs_incl,
        arg_requires=arg_requires_defs,
        arg_conflicts=arg_conflicts_defs
    )

    excl_expr, incl_expr, arg_requires_expr, arg_conflicts_expr = _emit_constraint_exprs(main_spec)
    main_args_expr = :($(_gr(:ArgDef))[$(argdefs_expr...)])

    main_common_kwargs = _emit_cli_common_kwargs_expr(
        usage,
        desc,
        epilog,
        main_args_expr,
        allow_extra,
        excl_expr,
        incl_expr,
        arg_requires_expr,
        arg_conflicts_expr
    )

    main_field_exprs = [:(getfield(_main_obj, $(QuoteNode(nm)))) for nm in ctor_args]
    final_ctor_expr = Expr(:call, struct_name, main_field_exprs..., nothing, nothing)

    struct_expr = Expr(
        :struct,
        false,
        struct_name,
        Expr(:block,
            fields...,
            :(subcommand::Union{Nothing,String}),
            :(subcommand_args::Union{Nothing,NamedTuple})
        )
    )

    main_parser_expr = _emit_parser_function(
        main_parser_name,
        main_result_expr,
        ctor_args,
        option_parse_stmts,
        positional_parse_stmts,
        post_stmts,
        gdefs_excl,
        gdefs_incl,
        arg_requires_defs,
        arg_conflicts_defs,
        allow_extra;
        strict_leftover=true
    )

    return esc(quote
        $struct_expr

        $main_parser_expr
        $(sub_parser_exprs...)

        function $(struct_name)(argv::Vector{String}=ARGS; allow_empty_option_value::Bool=false)
            local _path = String($(QuoteNode(string(struct_name))))
            local _main_argdefs = $main_args_expr

            local _sub = nothing
            local _sub_idx = 0
            if !isempty($(sub_names))
                local _flags_need_value, _flags_no_value = $(_gr(:_build_main_flag_sets))(_main_argdefs)
                (_sub, _sub_idx) = $(_gr(:_locate_subcommand))(argv, $(sub_names), _flags_need_value, _flags_no_value)
            end

            if !isnothing(_sub)
                local _flags_need_value, _flags_no_value = $(_gr(:_build_main_flag_sets))(_main_argdefs)
                local _main_argv, _sub_argv = $(_gr(:_extract_global_options))(argv, _sub_idx, _flags_need_value, _flags_no_value)

                if $(_gr(:_has_help_flag_before_dd))(_sub_argv)
                    $(sub_help_branches...)
                end

                local _main_obj = $(main_parser_name)(_main_argv; allow_empty_option_value=allow_empty_option_value)

                local _rest = _sub_argv
                $(dispatch_branches...)
            end

            if $(_gr(:_has_help_flag_before_dd))(argv)
                local _def = $(_gr(:CliDef))(
                    cmd_name = _path,
                    $(main_common_kwargs),
                    subcommands = $(_gr(:SubcommandDef))[$(sub_def_items...)]
                )
                throw($(_gr(:ArgHelpRequested))(_def, _path))
            end

            local _main_obj = $(main_parser_name)(argv; allow_empty_option_value=allow_empty_option_value)
            return $final_ctor_expr
        end
    end)
end


