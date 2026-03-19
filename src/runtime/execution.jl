
@inline function _throw_arg_error(msg::String)
    throw(ArgParseError(msg))
end

@inline function _throw_arg_error_ctx(name::AbstractString, expected::AbstractString, got; hint::AbstractString="")
    g = repr(got)
    msg = "Invalid value for $(name): expected $(expected), got $(g)"
    if !isempty(hint)
        msg *= ". " * String(hint)
    end
    throw(ArgParseError(msg))
end