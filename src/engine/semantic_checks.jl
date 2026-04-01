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

function _validate_relations!(ctx::_CompileCtx)
    for grp in ctx.group_defs_excl, s in grp
        _validate_option_ref!(ctx, "@GROUP_EXCL", s)
    end

    for grp in ctx.group_defs_incl, s in grp
        _validate_option_ref!(ctx, "@GROUP_INCL", s)
    end

    for rd in ctx.arg_requires_defs
        _validate_option_ref!(ctx, "@ARG_REQUIRES", rd.anchor)
        for s in rd.targets
            _validate_option_ref!(ctx, "@ARG_REQUIRES", s)
        end
    end

    for cd in ctx.arg_conflicts_defs
        _validate_option_ref!(ctx, "@ARG_CONFLICTS", cd.anchor)
        for s in cd.targets
            _validate_option_ref!(ctx, "@ARG_CONFLICTS", s)
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
