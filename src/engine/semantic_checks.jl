@inline _is_positional_kind(k::ArgKind) = k in (AK_POS_REQUIRED, AK_POS_OPTIONAL, AK_POS_REST)

@inline function _ensure_declared!(ctx::_CompileCtx, macro_name::String, s::Symbol)
    s in ctx.declared_names || throw(ArgumentError("$(macro_name) references unknown argument: $(s)"))
end

@inline function _ensure_option_style!(ctx::_CompileCtx, macro_name::String, s::Symbol)
    _is_positional_kind(get(ctx.name_kind, s, AK_OPTION)) &&
        throw(ArgumentError("$(macro_name) supports only option-style arguments, got positional: $(s)"))
end

@inline function _validate_option_ref!(ctx::_CompileCtx, macro_name::String, s::Symbol)
    _ensure_declared!(ctx, macro_name, s)
    _ensure_option_style!(ctx, macro_name, s)
end

function _validate_relation_expr!(ctx::_CompileCtx, macro_name::String, expr::RelationExpr)
    if expr isa RelAll
        !isempty(expr.members) || throw(ArgumentError("$(macro_name) all(...) must not be empty"))
        for s in expr.members
            _validate_option_ref!(ctx, macro_name, s)
        end
    elseif expr isa RelAny
        !isempty(expr.members) || throw(ArgumentError("$(macro_name) any(...) must not be empty"))
        for s in expr.members
            _validate_option_ref!(ctx, macro_name, s)
        end
    elseif expr isa RelNot
        _validate_relation_expr!(ctx, macro_name, expr.inner)
    else
        throw(ArgumentError("internal error: unsupported RelationExpr"))
    end
end

function _validate_relations!(ctx::_CompileCtx)
    for rel in ctx.relation_defs
        if rel.kind in (:depends, :conflicts)
            rel.lhs === nothing && throw(ArgumentError("relation $(rel.kind) requires lhs"))
            rel.rhs === nothing && throw(ArgumentError("relation $(rel.kind) requires rhs"))
            _validate_relation_expr!(ctx, "@ARGREL_$(uppercase(String(rel.kind)))", rel.lhs)
            _validate_relation_expr!(ctx, "@ARGREL_$(uppercase(String(rel.kind)))", rel.rhs)

        elseif rel.kind in (:atmostone, :atleastone, :onlyone, :allornone)
            isempty(rel.members) && throw(ArgumentError("relation $(rel.kind) requires members"))
            for s in rel.members
                _validate_option_ref!(ctx, "@ARGREL_$(uppercase(String(rel.kind)))", s)
            end

        else
            throw(ArgumentError("unsupported relation kind: $(rel.kind)"))
        end
    end

    seen_members = Dict{Symbol,String}()
    for gd in ctx.arg_group_defs
        for s in gd.members
            _ensure_declared!(ctx, "@ARG_GROUP", s)
            if haskey(seen_members, s)
                throw(ArgumentError("@ARG_GROUP argument $(s) is already assigned to group $(repr(seen_members[s]))"))
            end
            seen_members[s] = gd.title
        end
    end

    for nm in keys(ctx.fallback_map)
        _ensure_declared!(ctx, "fallback", nm)
    end

    for (src, dst) in ctx.fallback_map
        _ensure_declared!(ctx, "fallback", src)
        _ensure_declared!(ctx, "fallback", dst)

        src_kind = get(ctx.name_kind, src, AK_OPTION)
        dst_kind = get(ctx.name_kind, dst, AK_OPTION)

        src_kind in (AK_OPTION, AK_POS_OPTIONAL) ||
            throw(ArgumentError("fallback source must be an optional value-bearing argument: $(src)"))

        dst_kind in (AK_OPTION, AK_POS_OPTIONAL, AK_POS_REQUIRED) ||
            throw(ArgumentError("fallback target must be a value-bearing non-rest argument: $(dst)"))
    end

    _validate_fallback_cycles!(ctx.fallback_map)
end

function _validate_fallback_cycles!(fallback_map::Dict{Symbol,Symbol})
    visited = Dict{Symbol,Int}()

    function dfs(s::Symbol)
        state = get(visited, s, 0)
        if state == 1
            throw(ArgumentError("fallback cycle detected involving argument $(s)"))
        elseif state == 2
            return
        end

        visited[s] = 1
        if haskey(fallback_map, s)
            dfs(fallback_map[s])
        end
        visited[s] = 2
    end

    for s in keys(fallback_map)
        dfs(s)
    end
end
