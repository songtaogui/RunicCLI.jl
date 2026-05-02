export argerr, reqarg, badarg, dupkw, unknownkw, duplicate, internalerr

@inline argerr(msg::AbstractString) = throw(ArgumentError(String(msg)))

@inline function reqarg(ctx::AbstractString, what::AbstractString)
    argerr("$(ctx) expects $(what)")
end

@inline function badarg(ctx::AbstractString, what::AbstractString, got)
    argerr("$(ctx) invalid $(what): $(repr(got))")
end

@inline function dupkw(ctx::AbstractString, kw::Symbol)
    argerr("$(ctx) duplicate keyword: $(kw)")
end

@inline function unknownkw(ctx::AbstractString, kw::Symbol)
    argerr("$(ctx) unknown keyword: $(kw)")
end

@inline function duplicate(ctx::AbstractString, what::AbstractString)
    argerr("$(ctx) duplicated $(what)")
end

@inline function internalerr(msg::AbstractString)
    argerr("internal error: $(msg)")
end
