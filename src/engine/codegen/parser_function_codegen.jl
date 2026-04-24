function _compile_leftover_policy(allow_extra::Bool)
    if allow_extra
        return :(nothing)
    else
        return quote
            if !isempty(_args)
                local _hint = any($(_gr(:_looks_like_negative_number_token)), _args) ? " Hint: pass positional negative numbers after '--' (e.g. -- -1)." : ""
                $(_gr(:_throw_arg_error))($(_gr(:_msg_unknown_or_unexpected_arguments))(_args, _hint))
            end
        end
    end
end

function _emit_provided_bookkeeping(ctor_args::Vector{Symbol})
    provided_init = Expr[]
    provided_finalize = Expr[]

    for nm in ctor_args
        local provided_nm = Symbol("_provided_", nm)
        local cnt_nm = Symbol("_cnt_", nm)
        push!(provided_init, :(local $(provided_nm) = false))
        push!(provided_finalize, :(_provided_map[$(QuoteNode(nm))] = $(provided_nm)))
        push!(provided_finalize, :(_provided_count_map[$(QuoteNode(nm))] = (@isdefined($(cnt_nm)) ? $(cnt_nm) : Int($(provided_nm) ? 1 : 0))))
    end

    return provided_init, provided_finalize
end

function _emit_parser_function(
    fname::Symbol,
    result_type,
    fields::Vector{Expr},
    ctor_args::Vector{Symbol},
    option_parse_stmts::Vector{Expr},
    positional_parse_stmts::Vector{Expr},
    post_stmts::Vector{Expr},
    relation_defs,
    allow_extra::Bool;
    strict_leftover::Bool=true,
    auto_help::Bool=false,
    help_def_expr=:(nothing),
    help_path_expr=:(nothing)
)
    relation_checks = _compile_relation_checks(relation_defs)
    leftover_check = strict_leftover ? _compile_leftover_policy(allow_extra) : :(nothing)

    provided_init, provided_finalize = _emit_provided_bookkeeping(ctor_args)

    return_expr = if result_type isa Symbol
        :($(result_type)($([:( $(nm) ) for nm in ctor_args]...)))
    else
        result_type
    end

    unknown_option_check = allow_extra ? :(nothing) : :($(_gr(:_reject_unknown_option_tokens))(_opt_args))

    quote
        function $(fname)(argv::Vector{String}; allow_empty_option_value::Bool=false)
            if $(auto_help) && isempty(argv)
                local _help_def = $(help_def_expr)
                local _help_path = $(help_path_expr)
                if _help_path === nothing
                    throw($(_gr(:ArgHelpRequested))(_help_def))
                else
                    throw($(_gr(:ArgHelpRequested))(_help_def, _help_path))
                end
            end

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

            $(unknown_option_check)

            append!(_opt_args, _pos_after_dd)
            local _args::Vector{String} = _opt_args

            $(positional_parse_stmts...)

            $(post_stmts...)
            $(provided_finalize...)
            $(relation_checks...)
            $(leftover_check)

            return $(return_expr)
        end
    end
end

