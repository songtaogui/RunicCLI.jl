const _RC = @__MODULE__
_gr(s::Symbol) = GlobalRef(_RC, s)

function _compile_relation_checks(defs::Vector, kind::Symbol)
    checks = Expr[]

    if kind == :group_excl
        for grp in defs
            isempty(grp) && continue
            grp_names = [string(s) for s in grp]

            detail_blocks = Expr[]
            for (i, s) in enumerate(grp)
                push!(detail_blocks, quote
                    local _c = get(_provided_count_map, $(QuoteNode(s)), 0)
                    if _c > 0
                        _rel_count += 1
                        push!(_rel_details, $(grp_names[i]) * " x" * string(_c))
                    end
                end)
            end

            push!(checks, quote
                local _rel_count = 0
                local _rel_details = String[]
                $(detail_blocks...)
                if _rel_count > 1
                    $(_gr(:_throw_arg_error))($(_gr(:_msg_mutually_exclusive_args))($(grp_names), _rel_details))
                end
            end)
        end

    elseif kind == :group_incl
        for grp in defs
            isempty(grp) && continue
            grp_names = [string(s) for s in grp]

            detail_blocks = Expr[]
            for s in grp
                push!(detail_blocks, quote
                    if get(_provided_count_map, $(QuoteNode(s)), 0) > 0
                        _rel_count += 1
                    end
                end)
            end

            push!(checks, quote
                local _rel_count = 0
                $(detail_blocks...)
                if _rel_count < 1
                    $(_gr(:_throw_arg_error))($(_gr(:_msg_at_least_one_required))($(grp_names)))
                end
            end)
        end

    elseif kind == :requires
        for rd in defs
            anchor = rd.anchor
            targets = rd.targets
            isempty(targets) && continue
            target_names = [string(s) for s in targets]

            detail_blocks = Expr[]
            for (i, s) in enumerate(targets)
                push!(detail_blocks, quote
                    local _c = get(_provided_count_map, $(QuoteNode(s)), 0)
                    if _c > 0
                        _rel_target_count += 1
                        push!(_rel_target_details, $(target_names[i]) * " x" * string(_c))
                    end
                end)
            end

            push!(checks, quote
                local _rel_anchor_count = get(_provided_count_map, $(QuoteNode(anchor)), 0)
                if _rel_anchor_count > 0
                    local _rel_target_count = 0
                    local _rel_target_details = String[]
                    $(detail_blocks...)
                    if _rel_target_count < 1
                        $(_gr(:_throw_arg_error))($(_gr(:_msg_arg_requires))($(string(anchor)), $(target_names)))
                    end
                end
            end)
        end

    elseif kind == :conflicts
        for cd in defs
            anchor = cd.anchor
            targets = cd.targets
            isempty(targets) && continue
            target_names = [string(s) for s in targets]

            detail_blocks = Expr[]
            for (i, s) in enumerate(targets)
                push!(detail_blocks, quote
                    local _c = get(_provided_count_map, $(QuoteNode(s)), 0)
                    if _c > 0
                        push!(_rel_hits, $(target_names[i]) * " x" * string(_c))
                    end
                end)
            end

            push!(checks, quote
                local _rel_anchor_count = get(_provided_count_map, $(QuoteNode(anchor)), 0)
                if _rel_anchor_count > 0
                    local _rel_hits = String[]
                    $(detail_blocks...)
                    if !isempty(_rel_hits)
                        $(_gr(:_throw_arg_error))($(_gr(:_msg_arg_conflicts))($(string(anchor)), _rel_hits))
                    end
                end
            end)
        end
    else
        throw(ArgumentError("internal error: unsupported relation check kind $(kind)"))
    end

    return checks
end

_compile_group_exclusive_checks(group_defs::Vector{Vector{Symbol}}) =
    _compile_relation_checks(group_defs, :group_excl)

_compile_group_inclusion_checks(group_defs::Vector{Vector{Symbol}}) =
    _compile_relation_checks(group_defs, :group_incl)

_compile_arg_requires_checks(req_defs) =
    _compile_relation_checks(req_defs, :requires)

_compile_arg_conflicts_checks(conf_defs) =
    _compile_relation_checks(conf_defs, :conflicts)

function _build_relation_defs_exprs(gdefs_excl, gdefs_incl, arg_requires_defs, arg_conflicts_defs)
    excl_expr = Expr(:vect, [Expr(:vect, QuoteNode.(g)...) for g in gdefs_excl]...)
    incl_expr = Expr(:vect, [Expr(:vect, QuoteNode.(g)...) for g in gdefs_incl]...)

    req_expr = Expr(:vect, [
        :($(_gr(:ArgRequiresDef))(anchor=$(QuoteNode(rd.anchor)), targets=$(Expr(:vect, QuoteNode.(rd.targets)...))))
        for rd in arg_requires_defs
    ]...)

    conf_expr = Expr(:vect, [
        :($(_gr(:ArgConflictsDef))(anchor=$(QuoteNode(cd.anchor)), targets=$(Expr(:vect, QuoteNode.(cd.targets)...))))
        for cd in arg_conflicts_defs
    ]...)

    return excl_expr, incl_expr, req_expr, conf_expr
end


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
