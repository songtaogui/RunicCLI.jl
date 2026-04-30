@inline is_positional_kind(k::ArgKind) = k in (AK_POS_REQUIRED, AK_POS_OPTIONAL, AK_POS_REST)

@inline function ensure_declared!(ctx::CompileCtx, macro_name::String, s::Symbol)
    s in ctx.declared_names || throw(ArgumentError("$(macro_name) references unknown argument: $(s)"))
end

@inline function ensure_option_style!(ctx::CompileCtx, macro_name::String, s::Symbol)
    is_positional_kind(get(ctx.name_kind, s, AK_OPTION)) &&
        throw(ArgumentError("$(macro_name) supports only option-style arguments, got positional: $(s)"))
end

@inline function validate_option_ref!(ctx::CompileCtx, macro_name::String, s::Symbol)
    ensure_declared!(ctx, macro_name, s)
    ensure_option_style!(ctx, macro_name, s)
end

function validate_relation_expr!(ctx::CompileCtx, macro_name::String, expr::RelationExpr)
    if expr isa RelAll
        !isempty(expr.members) || throw(ArgumentError("$(macro_name) all(...) must not be empty"))
        for s in expr.members
            validate_option_ref!(ctx, macro_name, s)
        end
    elseif expr isa RelAny
        !isempty(expr.members) || throw(ArgumentError("$(macro_name) any(...) must not be empty"))
        for s in expr.members
            validate_option_ref!(ctx, macro_name, s)
        end
    elseif expr isa RelNot
        validate_relation_expr!(ctx, macro_name, expr.inner)
    else
        throw(ArgumentError("internal error: unsupported RelationExpr"))
    end
end

function validate_relations!(ctx::CompileCtx)
    for rel in ctx.relation_defs
        if rel.kind in (:depends, :conflicts)
            rel.lhs === nothing && throw(ArgumentError("relation $(rel.kind) requires lhs"))
            rel.rhs === nothing && throw(ArgumentError("relation $(rel.kind) requires rhs"))
            validate_relation_expr!(ctx, "@ARGREL_$(uppercase(String(rel.kind)))", rel.lhs)
            validate_relation_expr!(ctx, "@ARGREL_$(uppercase(String(rel.kind)))", rel.rhs)

        elseif rel.kind in (:atmostone, :atleastone, :onlyone, :allornone)
            isempty(rel.members) && throw(ArgumentError("relation $(rel.kind) requires members"))
            for s in rel.members
                validate_option_ref!(ctx, "@ARGREL_$(uppercase(String(rel.kind)))", s)
            end

        else
            throw(ArgumentError("unsupported relation kind: $(rel.kind)"))
        end
    end

    seen_members = Dict{Symbol,String}()
    for gd in ctx.arg_group_defs
        for s in gd.members
            ensure_declared!(ctx, "@ARG_GROUP", s)
            if haskey(seen_members, s)
                throw(ArgumentError("@ARG_GROUP argument $(s) is already assigned to group $(repr(seen_members[s]))"))
            end
            seen_members[s] = gd.title
        end
    end

    for nm in keys(ctx.fallback_map)
        ensure_declared!(ctx, "fallback", nm)
    end

    for (src, dst) in ctx.fallback_map
        ensure_declared!(ctx, "fallback", src)
        ensure_declared!(ctx, "fallback", dst)

        src_kind = get(ctx.name_kind, src, AK_OPTION)
        dst_kind = get(ctx.name_kind, dst, AK_OPTION)

        src_kind in (AK_OPTION, AK_POS_OPTIONAL) ||
            throw(ArgumentError("fallback source must be an optional value-bearing argument: $(src)"))

        dst_kind in (AK_OPTION, AK_POS_OPTIONAL, AK_POS_REQUIRED) ||
            throw(ArgumentError("fallback target must be a value-bearing non-rest argument: $(dst)"))
    end

    validate_fallback_cycles!(ctx.fallback_map)
end

function validate_fallback_cycles!(fallback_map::Dict{Symbol,Symbol})
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
