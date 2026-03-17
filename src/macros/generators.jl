# RunicCLI
# macros/generators.jl

"""
Generate parser function + metadata from command DSL.
"""

function _emit_parser_function(
    fname::Symbol,
    result_type,
    fields::Vector{Expr},
    ctor_args::Vector{Symbol},
    option_parse_stmts::Vector{Expr},
    positional_parse_stmts::Vector{Expr},
    post_stmts::Vector{Expr},
    group_defs::Vector{Vector{Symbol}},
    allow_extra::Bool;
    strict_leftover::Bool=true
)
    group_checks = _compile_group_exclusive_checks(group_defs)
    leftover_check = strict_leftover ? _compile_leftover_policy(allow_extra) : :(nothing)

    provided_init = Expr[]
    provided_finalize = Expr[]
    for nm in ctor_args
        local provided_nm = Symbol("_provided_", nm)
        local cnt_nm = Symbol("_cnt_", nm)
        push!(provided_init, :(local $(provided_nm) = false))
        push!(provided_finalize, :(_provided_map[$(QuoteNode(nm))] = $(provided_nm)))
        push!(provided_finalize, :(_provided_count_map[$(QuoteNode(nm))] = (@isdefined($(cnt_nm)) ? $(cnt_nm) : Int($(provided_nm) ? 1 : 0))))
    end

    return_expr = if result_type isa Symbol
        :($(result_type)($([:( $(nm) ) for nm in ctor_args]...)))
    else
        result_type
    end

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

            $(provided_init...)

            $(option_parse_stmts...)

            append!(_opt_args, _pos_after_dd)
            local _args::Vector{String} = _opt_args

            $(positional_parse_stmts...)

            $(post_stmts...)
            $(provided_finalize...)
            $(group_checks...)
            $(leftover_check)

            return $(return_expr)
        end
    end
end


"""
Helper to emit ArgDef vector expression.
"""
function _emit_argdefs(argdefs_expr::Vector{Expr})
    return :(ArgDef[$(argdefs_expr...)])
end
