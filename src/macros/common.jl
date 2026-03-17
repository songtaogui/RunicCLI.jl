const _RC = @__MODULE__
_gr(s::Symbol) = GlobalRef(_RC, s)

function _compile_group_exclusive_checks(group_defs::Vector{Vector{Symbol}})
    checks = Expr[]
    for grp in group_defs
        isempty(grp) && continue
        grp_names = [string(s) for s in grp]

        detail_blocks = Expr[]
        for (i, s) in enumerate(grp)
            push!(detail_blocks, quote
                local _c = get(_provided_count_map, $(QuoteNode(s)), 0)
                if _c > 0
                    _gx_count += 1
                    push!(_gx_details, $(grp_names[i]) * " x" * string(_c))
                end
            end)
        end

        push!(checks, quote
            local _gx_count = 0
            local _gx_details = String[]
            $(detail_blocks...)
            if _gx_count > 1
                $(_gr(:_throw_arg_error))("Mutually exclusive arguments provided together: " * join($(grp_names), ", ") * ". Details: " * join(_gx_details, "; "))
            end
        end)
    end
    return checks
end

function _compile_leftover_policy(allow_extra::Bool)
    if allow_extra
        return :(nothing)
    else
        return quote
            if !isempty(_args)
                local _hint = any($(_gr(:_looks_like_negative_number_token)), _args) ? " Hint: pass positional negative numbers after '--' (e.g. -- -1)." : ""
                $(_gr(:_throw_arg_error))("Unknown or unexpected arguments: " * join(_args, " ") * _hint)
            end
        end
    end
end
