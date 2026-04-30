"""Compile a relation expression into a boolean expression over provided-count map."""
function compile_relation_expr_eval(expr::RelationExpr, count_var::Symbol)
    if expr isa RelAll
        parts = [:(get($(count_var), $(QuoteNode(s)), 0) > 0) for s in expr.members]
        return isempty(parts) ? :(true) : reduce((a, b) -> :($a && $b), parts)
    elseif expr isa RelAny
        parts = [:(get($(count_var), $(QuoteNode(s)), 0) > 0) for s in expr.members]
        return isempty(parts) ? :(false) : reduce((a, b) -> :($a || $b), parts)
    elseif expr isa RelNot
        inner = compile_relation_expr_eval(expr.inner, count_var)
        return :(!($inner))
    else
        throw(ArgumentError("internal error: unsupported RelationExpr"))
    end
end

"""Collect all member symbols referenced by a relation expression."""
function compile_relation_expr_members(expr::RelationExpr)
    acc = Set{Symbol}()

    function walk(x::RelationExpr)
        if x isa RelAll
            foreach(s -> push!(acc, s), x.members)
        elseif x isa RelAny
            foreach(s -> push!(acc, s), x.members)
        elseif x isa RelNot
            walk(x.inner)
        else
            throw(ArgumentError("internal error: unsupported RelationExpr"))
        end
    end

    walk(expr)
    return collect(acc)
end

"""Return default human-readable error text for a relation kind."""
function compile_default_relation_message(rel)
    if rel.kind == :depends
        return "Argument relation violated: dependency condition not satisfied"
    elseif rel.kind == :conflicts
        return "Argument relation violated: conflicting conditions satisfied together"
    elseif rel.kind == :atmostone
        return "Argument relation violated: at most one of the specified arguments may be provided"
    elseif rel.kind == :atleastone
        return "Argument relation violated: at least one of the specified arguments must be provided"
    elseif rel.kind == :onlyone
        return "Argument relation violated: exactly one of the specified arguments must be provided"
    elseif rel.kind == :allornone
        return "Argument relation violated: either provide all specified arguments or provide none"
    else
        return "Argument relation violated"
    end
end

"""Compile all relation definitions into runtime validation statements."""
function compile_relation_checks(relation_defs)
    checks = Expr[]

    for rel in relation_defs
        msg = isempty(rel.help) ? compile_default_relation_message(rel) : rel.help

        if rel.kind == :depends
            lhs_eval = compile_relation_expr_eval(rel.lhs, :_provided_count_map)
            rhs_eval = compile_relation_expr_eval(rel.rhs, :_provided_count_map)

            push!(checks, quote
                if $(lhs_eval) && !($(rhs_eval))
                    $(_gr(:throw_arg_error))($(msg))
                end
            end)

        elseif rel.kind == :conflicts
            lhs_eval = compile_relation_expr_eval(rel.lhs, :_provided_count_map)
            rhs_eval = compile_relation_expr_eval(rel.rhs, :_provided_count_map)

            push!(checks, quote
                if $(lhs_eval) && $(rhs_eval)
                    $(_gr(:throw_arg_error))($(msg))
                end
            end)

        elseif rel.kind == :atmostone
            members = rel.members
            count_terms = [:(get(_provided_count_map, $(QuoteNode(s)), 0) > 0 ? 1 : 0) for s in members]
            count_expr = isempty(count_terms) ? :(0) : reduce((a, b) -> :($a + $b), count_terms)

            push!(checks, quote
                local _rel_count = $(count_expr)
                if _rel_count > 1
                    $(_gr(:throw_arg_error))($(msg))
                end
            end)

        elseif rel.kind == :atleastone
            members = rel.members
            count_terms = [:(get(_provided_count_map, $(QuoteNode(s)), 0) > 0 ? 1 : 0) for s in members]
            count_expr = isempty(count_terms) ? :(0) : reduce((a, b) -> :($a + $b), count_terms)

            push!(checks, quote
                local _rel_count = $(count_expr)
                if _rel_count < 1
                    $(_gr(:throw_arg_error))($(msg))
                end
            end)

        elseif rel.kind == :onlyone
            members = rel.members
            count_terms = [:(get(_provided_count_map, $(QuoteNode(s)), 0) > 0 ? 1 : 0) for s in members]
            count_expr = isempty(count_terms) ? :(0) : reduce((a, b) -> :($a + $b), count_terms)

            push!(checks, quote
                local _rel_count = $(count_expr)
                if _rel_count != 1
                    $(_gr(:throw_arg_error))($(msg))
                end
            end)

        elseif rel.kind == :allornone
            members = rel.members
            count_terms = [:(get(_provided_count_map, $(QuoteNode(s)), 0) > 0 ? 1 : 0) for s in members]
            count_expr = isempty(count_terms) ? :(0) : reduce((a, b) -> :($a + $b), count_terms)
            n = length(members)

            push!(checks, quote
                local _rel_count = $(count_expr)
                if !(_rel_count == 0 || _rel_count == $(n))
                    $(_gr(:throw_arg_error))($(msg))
                end
            end)

        else
            throw(ArgumentError("internal error: unsupported relation kind $(rel.kind)"))
        end
    end

    return checks
end
