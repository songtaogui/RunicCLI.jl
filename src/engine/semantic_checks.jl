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
end
