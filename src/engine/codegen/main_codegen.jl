function _build_main_parser_expr(
    struct_name, usage, desc, epilog, version, allow_extra,
    fields, ctor_args, option_parse_stmts, positional_parse_stmts, post_stmts, argdefs_expr,
    gdefs_excl, gdefs_incl, arg_requires_defs, arg_conflicts_defs,
    sub_def_items, sub_parser_exprs, dispatch_branches, sub_help_branches, sub_version_branches, sub_names
)
    main_parser_name = gensym(:parse_main)
    main_result_expr = :( (; $(ctor_args...)) )

    main_help_def_expr = _build_clidef_expr(
        :(_path), usage, desc, epilog, version,
        :(_main_argdefs),
        :($(_gr(:SubcommandDef))[$(sub_def_items...)]),
        allow_extra, gdefs_excl, gdefs_incl, arg_requires_defs, arg_conflicts_defs
    )

    return esc(quote
        struct $(struct_name)
            $(fields...)
            subcommand::Union{Nothing,String}
            subcommand_args::Union{Nothing,NamedTuple}
        end

        $(_emit_parser_function(
            main_parser_name,
            main_result_expr,
            fields,
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
        ))
        $(sub_parser_exprs...)

        function $(struct_name)(
            argv::Vector{String}=ARGS;
            allow_empty_option_value::Bool=false,
            env::AbstractDict=ENV,
            config::AbstractDict=Dict{String,Any}(),
            config_file::Union{Nothing,String}=nothing
        )
            local _path = String($(QuoteNode(string(struct_name))))
            local _main_argdefs = $(_gr(:ArgDef))[$(argdefs_expr...)]

            local _cfg = isempty(config) ? Dict{String,Any}() : Dict{String,Any}(string(k)=>v for (k,v) in pairs(config))
            if config_file !== nothing
                local _f = $(_gr(:load_config_file))(config_file)
                merge!(_cfg, _f)
            end

            local _argv0 = copy(argv)
            local _argv_main_merged = $(_gr(:merge_cli_sources))(_argv0, _main_argdefs; env=env, config=_cfg)

            local _sub = nothing
            local _sub_idx = 0
            if !isempty($(sub_names))
                local _flags_need_value, _flags_no_value = $(_gr(:_build_main_flag_sets))(_main_argdefs)
                (_sub, _sub_idx) = $(_gr(:_locate_subcommand))(_argv_main_merged, $(sub_names), _flags_need_value, _flags_no_value)
            end

            if !isnothing(_sub)
                local _flags_need_value, _flags_no_value = $(_gr(:_build_main_flag_sets))(_main_argdefs)
                local _main_argv, _sub_argv = $(_gr(:_extract_global_options))(_argv_main_merged, _sub_idx, _flags_need_value, _flags_no_value)

                if $(_gr(:_has_version_flag_before_dd))(_sub_argv)
                    $(sub_version_branches...)
                end

                if $(_gr(:_has_help_flag_before_dd))(_sub_argv)
                    $(sub_help_branches...)
                end

                local _main_obj = $(main_parser_name)(_main_argv; allow_empty_option_value=allow_empty_option_value)
                local _rest = _sub_argv
                $(dispatch_branches...)
            end

            if $(_gr(:_has_version_flag_before_dd))(_argv_main_merged)
                throw($(_gr(:ArgHelpRequested))($(version)))
            end

            if $(_gr(:_has_help_flag_before_dd))(_argv_main_merged)
                local _def = $(main_help_def_expr)
                throw($(_gr(:ArgHelpRequested))(_def, _path))
            end

            local _main_obj = $(main_parser_name)(_argv_main_merged; allow_empty_option_value=allow_empty_option_value)
            return $(struct_name)($([:(getfield(_main_obj, $(QuoteNode(nm)))) for nm in ctor_args]...), nothing, nothing)
        end

    end)
end