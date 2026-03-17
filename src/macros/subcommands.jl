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

        s_fields, s_option_parse_stmts, s_positional_parse_stmts, s_post_stmts, s_argdefs_expr, s_gdefs = _compile_cmd_block(sub_main_block)
        s_ctor_args = [f.args[1] for f in s_fields]

        s_parser_name = gensym(Symbol("parse_sub_", replace(sub_name, r"[^A-Za-z0-9_]" => "_")))
        s_nt_expr = :( (; $(s_ctor_args...)) )

        s_parser_expr = _emit_parser_function(
            s_parser_name,
            :($s_nt_expr),
            s_fields,
            s_ctor_args,
            s_option_parse_stmts,
            s_positional_parse_stmts,
            s_post_stmts,
            s_gdefs,
            sub_allow_extra
        )

        main_field_exprs = [:(getfield(_main_obj, $(QuoteNode(nm)))) for nm in main_ctor_args]

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
                    usage = $(sub_usage),
                    description = $(sub_desc),
                    epilog = $(sub_epilog),
                    args = $(_gr(:ArgDef))[$(s_argdefs_expr...)],
                    subcommands = $(_gr(:SubcommandDef))[],
                    allow_extra = $(sub_allow_extra),
                    mutual_exclusion_groups = $(Expr(:vect, [Expr(:vect, QuoteNode.(g)...) for g in s_gdefs]...))
                )
                throw($(_gr(:ArgHelpRequested))($(_gr(:render_help))(_sub_def; path=_path * " " * $(sub_name))))
            end
        end)

        push!(sub_def_items, :($(_gr(:SubcommandDef))(
            name=$(sub_name),
            description=$(sub_desc),
            usage=$(sub_usage),
            epilog=$(sub_epilog),
            body=nothing,
            args=$(_gr(:ArgDef))[$(s_argdefs_expr...)],
            allow_extra=$(sub_allow_extra),
            mutual_exclusion_groups=$(Expr(:vect, [Expr(:vect, QuoteNode.(g)...) for g in s_gdefs]...))
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
    gdefs, sub_def_items, sub_parser_exprs, dispatch_branches, sub_help_branches, sub_names
)
    main_parser_name = gensym(:parse_main)
    main_result_expr = :( (; $(ctor_args...)) )

    return esc(quote
        struct $(struct_name)
            $(fields...)
            subcommand::Union{Nothing,String}
            subcommand_args::Union{Nothing,NamedTuple}
        end

        $(_emit_parser_function(main_parser_name, main_result_expr, fields, ctor_args, option_parse_stmts, positional_parse_stmts, post_stmts, gdefs, allow_extra; strict_leftover=true))
        $(sub_parser_exprs...)

        function $(struct_name)(argv::Vector{String}=ARGS; allow_empty_option_value::Bool=false)
            local _path = String($(QuoteNode(string(struct_name))))
            local _main_argdefs = $(_gr(:ArgDef))[$(argdefs_expr...)]

            local _sub = nothing
            local _sub_idx = 0
            if !isempty($(sub_names))
                local _flags_need_value = Set{String}()
                local _flags_no_value = Set{String}()

                for a in _main_argdefs
                    if a.kind in ($(_gr(:AK_OPTION)), $(_gr(:AK_OPTION_MULTI)))
                        for f in a.flags
                            push!(_flags_need_value, f)
                        end
                    elseif a.kind in ($(_gr(:AK_FLAG)), $(_gr(:AK_COUNT)))
                        for f in a.flags
                            push!(_flags_no_value, f)
                        end
                    end
                end

                (_sub, _sub_idx) = $(_gr(:_locate_subcommand))(argv, $(sub_names), _flags_need_value, _flags_no_value)
            end

            if !isnothing(_sub)
                local _main_argv = argv[1:_sub_idx-1]
                local _sub_argv = argv[_sub_idx+1:end]

                local _main_obj = $(main_parser_name)(_main_argv; allow_empty_option_value=allow_empty_option_value)

                if $(_gr(:_has_help_flag_before_dd))(_sub_argv)
                    $(sub_help_branches...)
                end

                local _rest = _sub_argv
                $(dispatch_branches...)
            end

            if $(_gr(:_has_help_flag_before_dd))(argv)
                local _def = $(_gr(:CliDef))(
                    cmd_name = _path,
                    usage = $(usage),
                    description = $(desc),
                    epilog = $(epilog),
                    args = _main_argdefs,
                    subcommands = $(_gr(:SubcommandDef))[$(sub_def_items...)],
                    allow_extra = $(allow_extra),
                    mutual_exclusion_groups = $(Expr(:vect, [Expr(:vect, QuoteNode.(g)...) for g in gdefs]...))
                )
                throw($(_gr(:ArgHelpRequested))($(_gr(:render_help))(_def; path=_path)))
            end

            local _main_obj = $(main_parser_name)(argv; allow_empty_option_value=allow_empty_option_value)
            return $(struct_name)($([:(getfield(_main_obj, $(QuoteNode(nm)))) for nm in ctor_args]...), nothing, nothing)
        end
    end)
end




