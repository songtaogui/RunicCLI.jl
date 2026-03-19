
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

@inline function _uninit_for_field_type(T::Type)
    if T === Bool
        return false
    elseif T <: Integer
        return zero(T)
    elseif T <: AbstractFloat
        return zero(T)
    elseif T <: AbstractVector
        return T()
    elseif T === Nothing
        return nothing
    end

    try
        nothing isa T && return nothing
    catch
    end

    throw(ArgumentError("Cannot initialize parser variable for field type $(T)"))
end
