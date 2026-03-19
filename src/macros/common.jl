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

function _compile_group_inclusion_checks(group_defs::Vector{Vector{Symbol}})
    checks = Expr[]
    for grp in group_defs
        isempty(grp) && continue
        grp_names = [string(s) for s in grp]

        detail_blocks = Expr[]
        for (i, s) in enumerate(grp)
            push!(detail_blocks, quote
                local _c = get(_provided_count_map, $(QuoteNode(s)), 0)
                if _c > 0
                    _gi_count += 1
                    push!(_gi_details, $(grp_names[i]) * " x" * string(_c))
                end
            end)
        end

        push!(checks, quote
            local _gi_count = 0
            local _gi_details = String[]
            $(detail_blocks...)
            if _gi_count < 1
                $(_gr(:_throw_arg_error))("At least one of the following arguments must be provided: " * join($(grp_names), ", "))
            end
        end)
    end
    return checks
end

function _compile_arg_requires_checks(req_defs)
    checks = Expr[]
    for rd in req_defs
        anchor = rd.anchor
        targets = rd.targets
        isempty(targets) && continue

        target_names = [string(s) for s in targets]

        detail_blocks = Expr[]
        for (i, s) in enumerate(targets)
            push!(detail_blocks, quote
                local _c = get(_provided_count_map, $(QuoteNode(s)), 0)
                if _c > 0
                    _ar_target_count += 1
                    push!(_ar_target_details, $(target_names[i]) * " x" * string(_c))
                end
            end)
        end

        push!(checks, quote
            local _ar_anchor_count = get(_provided_count_map, $(QuoteNode(anchor)), 0)
            if _ar_anchor_count > 0
                local _ar_target_count = 0
                local _ar_target_details = String[]
                $(detail_blocks...)
                if _ar_target_count < 1
                    $(_gr(:_throw_arg_error))(
                        "Argument " * $(string(anchor)) * " requires at least one of: " * join($(target_names), ", ")
                    )
                end
            end
        end)
    end
    return checks
end

function _compile_arg_conflicts_checks(conf_defs)
    checks = Expr[]
    for cd in conf_defs
        anchor = cd.anchor
        targets = cd.targets
        isempty(targets) && continue

        target_names = [string(s) for s in targets]

        detail_blocks = Expr[]
        for (i, s) in enumerate(targets)
            push!(detail_blocks, quote
                local _c = get(_provided_count_map, $(QuoteNode(s)), 0)
                if _c > 0
                    push!(_ac_hits, $(target_names[i]) * " x" * string(_c))
                end
            end)
        end

        push!(checks, quote
            local _ac_anchor_count = get(_provided_count_map, $(QuoteNode(anchor)), 0)
            if _ac_anchor_count > 0
                local _ac_hits = String[]
                $(detail_blocks...)
                if !isempty(_ac_hits)
                    $(_gr(:_throw_arg_error))(
                        "Argument " * $(string(anchor)) * " conflicts with: " * join(_ac_hits, ", ")
                    )
                end
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