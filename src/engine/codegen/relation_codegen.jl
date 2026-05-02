# ---------- relation expr eval (multiple dispatch) ----------
compile_relation_expr_eval(expr::RelAll, count_var::Symbol) =
    isempty(expr.members) ? :(true) :
    reduce((a, b) -> :($a && $b),
           (:(get($(count_var), $(QuoteNode(s)), 0) > 0) for s in expr.members))

compile_relation_expr_eval(expr::RelAny, count_var::Symbol) =
    isempty(expr.members) ? :(false) :
    reduce((a, b) -> :($a || $b),
           (:(get($(count_var), $(QuoteNode(s)), 0) > 0) for s in expr.members))

compile_relation_expr_eval(expr::RelNot, count_var::Symbol) =
    :(!($(compile_relation_expr_eval(expr.inner, count_var))))

# ---------- default message by kind ----------
compile_default_relation_message(::Val{:depends})    = "Argument relation violated: dependency condition not satisfied"
compile_default_relation_message(::Val{:conflicts})  = "Argument relation violated: conflicting conditions satisfied together"
compile_default_relation_message(::Val{:atmostone})  = "Argument relation violated: at most one of the specified arguments may be provided"
compile_default_relation_message(::Val{:atleastone}) = "Argument relation violated: at least one of the specified arguments must be provided"
compile_default_relation_message(::Val{:onlyone})    = "Argument relation violated: exactly one of the specified arguments must be provided"
compile_default_relation_message(::Val{:allornone})  = "Argument relation violated: either provide all specified arguments or provide none"
compile_default_relation_message(::Val)              = "Argument relation violated"

# ---------- small builders ----------
@inline function _member_presence_count_expr(members::Vector{Symbol})
    terms = [:(get(_provided_count_map, $(QuoteNode(s)), 0) > 0 ? 1 : 0) for s in members]
    isempty(terms) ? :(0) : reduce((a, b) -> :($a + $b), terms)
end

@inline function emit_relation_binary_check(lhs_eval, rhs_eval, msg, pred::Function)
    cond = pred(lhs_eval, rhs_eval)
    return quote
        if $(cond)
            $(_gr(:throw_arg_error))($(msg))
        end
    end
end

@inline function emit_relation_count_check(count_expr, msg, cond_expr)
    quote
        local _rel_count = $(count_expr)
        if $(cond_expr)
            $(_gr(:throw_arg_error))($(msg))
        end
    end
end

# ---------- kind-dispatched emit ----------
function compile_relation_check(rel::ArgRelationDef)
    msg = isempty(rel.help) ? compile_default_relation_message(Val(rel.kind)) : rel.help
    return compile_relation_check(Val(rel.kind), rel, msg)
end

function compile_relation_check(::Val{:depends}, rel::ArgRelationDef, msg::String)
    lhs_eval = compile_relation_expr_eval(rel.lhs, :_provided_count_map)
    rhs_eval = compile_relation_expr_eval(rel.rhs, :_provided_count_map)
    emit_relation_binary_check(lhs_eval, rhs_eval, msg, (l, r) -> :($l && !($r)))
end

function compile_relation_check(::Val{:conflicts}, rel::ArgRelationDef, msg::String)
    lhs_eval = compile_relation_expr_eval(rel.lhs, :_provided_count_map)
    rhs_eval = compile_relation_expr_eval(rel.rhs, :_provided_count_map)
    emit_relation_binary_check(lhs_eval, rhs_eval, msg, (l, r) -> :($l && $r))
end

function compile_relation_check(::Val{:atmostone}, rel::ArgRelationDef, msg::String)
    c = _member_presence_count_expr(rel.members)
    emit_relation_count_check(c, msg, :(_rel_count > 1))
end

function compile_relation_check(::Val{:atleastone}, rel::ArgRelationDef, msg::String)
    c = _member_presence_count_expr(rel.members)
    emit_relation_count_check(c, msg, :(_rel_count < 1))
end

function compile_relation_check(::Val{:onlyone}, rel::ArgRelationDef, msg::String)
    c = _member_presence_count_expr(rel.members)
    emit_relation_count_check(c, msg, :(_rel_count != 1))
end

function compile_relation_check(::Val{:allornone}, rel::ArgRelationDef, msg::String)
    c = _member_presence_count_expr(rel.members)
    n = length(rel.members)
    emit_relation_count_check(c, msg, :(!(_rel_count == 0 || _rel_count == $(n))))
end

compile_relation_check(::Val, rel::ArgRelationDef, msg::String) =
    internalerr("unsupported relation kind $(rel.kind)")

function compile_relation_checks(relation_defs::Vector{ArgRelationDef})
    [compile_relation_check(rel) for rel in relation_defs]
end
