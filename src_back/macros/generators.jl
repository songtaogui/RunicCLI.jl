# RunicCLI
# macros/generators.jl
function _emit_parser_var_decls(ctor_args::Vector{Symbol}, result_expr)
    decls = Expr[]
    for nm in ctor_args
        push!(decls, :($(nm) = nothing))
    end
    return decls
end

function _emit_parser_function(
    fname::Symbol,
    result_expr,
    ctor_args::Vector{Symbol},
    option_parse_stmts::Vector{Expr},
    positional_parse_stmts::Vector{Expr},
    post_stmts::Vector{Expr},
    group_defs_excl::Vector{Vector{Symbol}},
    group_defs_incl::Vector{Vector{Symbol}},
    arg_requires_defs,
    arg_conflicts_defs,
    allow_extra::Bool;
    strict_leftover::Bool=true
)
    group_checks_excl = _compile_group_exclusive_checks(group_defs_excl)
    group_checks_incl = _compile_group_inclusion_checks(group_defs_incl)
    arg_requires_checks = _compile_arg_requires_checks(arg_requires_defs)
    arg_conflicts_checks = _compile_arg_conflicts_checks(arg_conflicts_defs)
    leftover_check = strict_leftover ? _compile_leftover_policy(allow_extra) : :(nothing)

    provided_init = Expr[]
    provided_finalize = Expr[]
    count_init = Expr[]
    parser_var_decls = _emit_parser_var_decls(ctor_args, result_expr)

    for nm in ctor_args
        provided_nm = Symbol("_provided_", nm)
        cnt_nm = Symbol("_cnt_", nm)

        push!(provided_init, :($(provided_nm) = false))
        push!(count_init, :($(cnt_nm) = 0))

        push!(provided_finalize, :(_provided_map[$(QuoteNode(nm))] = $(provided_nm)))
        push!(provided_finalize, :(_provided_count_map[$(QuoteNode(nm))] = $(cnt_nm) > 0 ? $(cnt_nm) : Int($(provided_nm) ? 1 : 0)))
    end

    unknown_option_check = allow_extra ? :(nothing) : :($(_gr(:_reject_unknown_option_tokens))(_opt_args))

    quote
        function $(fname)(argv::Vector{String}; allow_empty_option_value::Bool=false)
            local _args_all = $(_gr(:_split_arguments))(copy(argv))
            local _dd = findfirst(==("--"), _args_all)

            local _pre_dd::Vector{String}
            local _pos_after_dd::Vector{String}

            if isnothing(_dd)
                _pre_dd = _args_all
                _pos_after_dd = String[]
            else
                _pre_dd = _args_all[1:_dd-1]
                _pos_after_dd = _args_all[_dd+1:end]
            end

            local _opt_args::Vector{String} = _pre_dd
            local _provided_map = Dict{Symbol,Bool}()
            local _provided_count_map = Dict{Symbol,Int}()

            $(parser_var_decls...)
            $(provided_init...)
            $(count_init...)

            $(option_parse_stmts...)

            $(unknown_option_check)

            append!(_opt_args, _pos_after_dd)
            local _args::Vector{String} = _opt_args

            $(positional_parse_stmts...)

            $(post_stmts...)
            $(provided_finalize...)
            $(group_checks_excl...)
            $(group_checks_incl...)
            $(arg_requires_checks...)
            $(arg_conflicts_checks...)
            $(leftover_check)

            return $(result_expr)
        end
    end
end

"""
Helper to emit ArgDef vector expression.
"""
function _emit_argdefs(argdefs_expr::Vector{Expr})
    return :(ArgDef[$(argdefs_expr...)])
end
