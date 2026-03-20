Base.@kwdef struct NormalizedSubCmd
    name::String
    description::String = ""
    usage::String = ""
    epilog::String = ""
    version::String = ""
    block::Expr
    allow_extra::Bool = false
end

function _build_clidef_expr(cmd_name_expr, usage_expr, desc_expr, epilog_expr, version_expr, args_expr, subcommands_expr, allow_extra, gdefs_excl, gdefs_incl, arg_requires_defs, arg_conflicts_defs)
    excl_expr, incl_expr, req_expr, conf_expr = _build_relation_defs_exprs(gdefs_excl, gdefs_incl, arg_requires_defs, arg_conflicts_defs)

    return :($(_gr(:CliDef))(
        cmd_name = $(cmd_name_expr),
        usage = $(usage_expr),
        description = $(desc_expr),
        epilog = $(epilog_expr),
        version = $(version_expr),
        args = $(args_expr),
        subcommands = $(subcommands_expr),
        allow_extra = $(allow_extra),
        mutual_exclusion_groups = $(excl_expr),
        mutual_inclusion_groups = $(incl_expr),
        arg_requires = $(req_expr),
        arg_conflicts = $(conf_expr)
    ))
end

function _build_subcommand_def_expr(
    sub_name, sub_desc, sub_usage, sub_epilog, sub_version,
    s_argdefs_expr, sub_allow_extra,
    s_gdefs_excl, s_gdefs_incl, s_arg_requires_defs, s_arg_conflicts_defs
)
    s_excl_expr, s_incl_expr, s_req_expr, s_conf_expr =
        _build_relation_defs_exprs(s_gdefs_excl, s_gdefs_incl, s_arg_requires_defs, s_arg_conflicts_defs)

    return :($(_gr(:SubcommandDef))(
        name=$(sub_name),
        description=$(sub_desc),
        usage=$(sub_usage),
        epilog=$(sub_epilog),
        version=$(sub_version),
        body=nothing,
        args=$(_gr(:ArgDef))[$(s_argdefs_expr...)],
        allow_extra=$(sub_allow_extra),
        mutual_exclusion_groups=$(s_excl_expr),
        mutual_inclusion_groups=$(s_incl_expr),
        arg_requires=$(s_req_expr),
        arg_conflicts=$(s_conf_expr)
    ))
end

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

        s_excl_expr, s_incl_expr, s_req_expr, s_conf_expr =
            _build_relation_defs_exprs(s_gdefs_excl, s_gdefs_incl, s_arg_requires_defs, s_arg_conflicts_defs)

        push!(sub_def_items, _build_subcommand_def_expr(
            sub_name, sub_desc, sub_usage, sub_epilog, sub_version,
            s_argdefs_expr, sub_allow_extra,
            s_gdefs_excl, s_gdefs_incl, s_arg_requires_defs, s_arg_conflicts_defs
        ))
    end

    return sub_def_items, sub_parser_exprs, dispatch_branches, sub_help_branches, sub_version_branches, sub_names
end

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
            env_prefix::String="",
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
            local _argv_main_merged = $(_gr(:merge_cli_sources))(_argv0, _main_argdefs; env_prefix=env_prefix, env=env, config=_cfg)

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


