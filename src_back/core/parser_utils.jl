# RunicCLI
# parser_utils.jl

function _split_multiflag(s::AbstractString)::Vector{String}
    # Classic short-option bundling:
    # -abc => -a -b -c
    # Any non-ASCII-letter in bundle is rejected to avoid ambiguous semantics.
    isascii(s) || _throw_arg_error("Invalid short option bundle (non-ASCII): $s")
    out = String[]
    max_i = lastindex(s)
    i = 2
    while i <= max_i
        c = s[i]
        if isascii(c) && isletter(c)
            push!(out, "-$c")
            i = nextind(s, i)
        else
            _throw_arg_error("Invalid short option bundle: $s")
        end
    end
    out
end

function _split_arguments(args::Vector{String}; allow_short_bundle::Bool=true)::Vector{String}
    out = String[]
    passthrough = false
    for arg in args
        if passthrough
            push!(out, arg)
            continue
        end
        if arg == "--"
            push!(out, arg)
            passthrough = true
            continue
        end
        if startswith(arg, "-")
            parts = split(arg, '=', limit=2)
            head = parts[1]
            is_short_bundle = allow_short_bundle &&
                              length(head) > 2 &&
                              head[2] != '-' &&
                              isascii(head[2]) &&
                              isletter(head[2])

            if is_short_bundle
                if length(parts) == 2
                    _throw_arg_error("Ambiguous short bundle with '=' is not allowed: $arg. Use '-a -b -c' or '--long=value'.")
                end
                if length(head) > 2 && isletter(head[2]) && (tryparse(Float64, head[3:end]) !== nothing)
                    push!(out, head[1:2])
                    push!(out, head[3:end])
                else
                    append!(out, _split_multiflag(head))
                end
            else
                append!(out, String.(parts))
            end
        else
            push!(out, arg)
        end
    end
    out
end

function _has_help_flag_before_dd(args::Vector{String})::Bool
    toks = _split_arguments(copy(args))
    dd = findfirst(==("--"), toks)
    if !isnothing(dd)
        toks = toks[1:dd-1]
    end
    any(t -> t == "-h" || t == "--help", toks)
end

@inline _find_flag(args::Vector{String}, flags::Vector{String}) = findfirst(in(flags), args)

@inline _looks_like_flag_token(s::String) = startswith(s, "-") && s != "-"
@inline _looks_like_negative_number_token(s::String) = startswith(s, "-") && tryparse(Float64, s) !== nothing

function _scan_delete_count!(args::Vector{String}, pred::F) where {F}
    count = 0
    i = 1
    while i <= length(args)
        if pred(args[i])
            deleteat!(args, i)
            count += 1
        else
            i += 1
        end
    end
    return count
end

function _pop_flag!(args::Vector{String}, flags::Vector{String})::Bool
    return _scan_delete_count!(args, x -> x in flags) > 0
end

function _pop_count!(args::Vector{String}, flag::String)::Int
    return _scan_delete_count!(args, ==(flag))
end


function _pop_value!(args::Vector{String}, flags::Vector{String}, allow_empty_option_value::Bool)::Union{Nothing,String}
    idx = _find_flag(args, flags)
    isnothing(idx) && return nothing
    idx == length(args) && _throw_arg_error("Option $(args[idx]) requires a value")

    val = args[idx+1]

    if !allow_empty_option_value && isempty(val)
        _throw_arg_error("Option $(args[idx]) does not allow empty value (use an explicit non-empty value)")
    end

    if _looks_like_flag_token(val) && !_looks_like_negative_number_token(val)
        _throw_arg_error("Option $(args[idx]) requires a value, but got another option token: $(val)")
    end

    deleteat!(args, (idx, idx+1))
    return val
end

function _pop_value_last!(args::Vector{String}, flags::Vector{String}, allow_empty_option_value::Bool)::Tuple{Union{Nothing,String},Bool}
    vals = String[]
    while true
        v = _pop_value!(args, flags, allow_empty_option_value)
        isnothing(v) && break
        push!(vals, v)
    end
    isempty(vals) && return (nothing, false)
    return (vals[end], true)
end

function _pop_value_once!(args::Vector{String}, flags::Vector{String}, name::String, allow_empty_option_value::Bool)::Tuple{Union{Nothing,String},Bool}
    vals = _pop_multi_values!(args, flags, allow_empty_option_value)
    if isempty(vals)
        return (nothing, false)
    elseif length(vals) == 1
        return (vals[1], true)
    else
        _throw_arg_error("Option $(flags[end]) specified multiple times for $(name)")
    end
end

function _pop_multi_values!(args::Vector{String}, flags::Vector{String}, allow_empty_option_value::Bool)::Vector{String}
    vals = String[]
    while true
        v = _pop_value!(args, flags, allow_empty_option_value)
        isnothing(v) && break
        push!(vals, v)
    end
    vals
end


# Parsing strategy for CLI string input:
# 1) tryparse(T, s) when applicable
# 2) parse(T, s) when applicable
# 3) T(s) as last fallback
# @inline _parse_value(::Type{String}, s::String, ::String) = s
# @inline _parse_value(::Type{Symbol}, s::String, ::String) = Symbol(s)
# @inline _parse_value(::Type{Bool}, s::String, name::String) = begin
#     x = lowercase(strip(s))
#     if x in ("1","true","t","yes","y","on")
#         true
#     elseif x in ("0","false","f","no","n","off")
#         false
#     else
#         _throw_arg_error("Invalid boolean value for $name: $s")
#     end
# end

# @inline function _parse_value(::Type{T}, s::String, name::String) where {T<:Integer}
#     try
#         return parse(T, s)
#     catch
#         _throw_arg_error("Invalid integer value for $name: $s")
#     end
# end

# @inline function _parse_value(::Type{T}, s::String, name::String) where {T<:AbstractFloat}
#     try
#         return parse(T, s)
#     catch
#         _throw_arg_error("Invalid floating value for $name: $s")
#     end
# end

@inline _parse_value(::Type{String}, s::String, ::String) = s
@inline _parse_value(::Type{Symbol}, s::String, ::String) = Symbol(s)

@inline function _parse_value(::Type{Bool}, s::String, name::String)
    x = lowercase(strip(s))
    if x in ("1", "true", "t", "yes", "y", "on")
        return true
    elseif x in ("0", "false", "f", "no", "n", "off")
        return false
    end
    _throw_arg_error("Invalid boolean value for $name: $s")
end

@inline function _parse_value(::Type{T}, s::String, name::String) where {T<:Integer}
    try
        return parse(T, s)
    catch
        _throw_arg_error("Invalid integer value for $name: $s")
    end
end

@inline function _parse_value(::Type{T}, s::String, name::String) where {T<:AbstractFloat}
    try
        return parse(T, s)
    catch
        _throw_arg_error("Invalid floating value for $name: $s")
    end
end

@inline function _parse_value_fallback(::Type{T}, s::String, name::String) where {T}
    if applicable(Base.tryparse, T, s)
        local tp = Base.tryparse(T, s)
        tp !== nothing && return tp
    end

    local parse_err = nothing
    if applicable(parse, T, s)
        try
            return parse(T, s)
        catch e
            parse_err = e
        end
    end

    try
        return T(s)
    catch e
        if parse_err === nothing
            _throw_arg_error("Invalid value for $name (type $(T)): $s ($(sprint(showerror, e)))")
        else
            _throw_arg_error("Invalid value for $name (type $(T)): $s (parse: $(sprint(showerror, parse_err)); ctor: $(sprint(showerror, e)))")
        end
    end
end

@inline _parse_value(::Type{T}, s::String, name::String) where {T} = _parse_value_fallback(T, s, name)


# Default conversion strategy is different:
# - defaults are converted via convert(T, v)
# - defaults do not go through string parsing pipeline
@inline function _convert_default(::Type{T}, v, name::String) where {T}
    try
        return v isa T ? v : convert(T, v)
    catch e
        _throw_arg_error("Invalid default value for $name: expected $T, got $(typeof(v)) ($(sprint(showerror, e)))")
    end
end

function _locate_subcommand(
    argv::Vector{String},
    sub_names::Vector{String},
    flags_need_value::Set{String},
    flags_no_value::Set{String};
    strict_unknown_option::Bool=true
)::Tuple{Union{Nothing,String},Int}
    isempty(sub_names) && return (nothing, 0)

    expecting_value = false

    i = 1
    while i <= length(argv)
        tok = argv[i]

        if tok == "--"
            return (nothing, 0)
        end

        if expecting_value
            expecting_value = false
            i += 1
            continue
        end

        if startswith(tok, "-") && tok != "-"
            parts = split(tok, '=', limit=2)
            head = parts[1]
            has_inline_value = (length(parts) == 2)

            if head in flags_need_value
                if !has_inline_value
                    expecting_value = true
                end
                i += 1
                continue
            elseif head in flags_no_value
                i += 1
                continue
            else
                if startswith(head, "-") && !startswith(head, "--") && length(head) > 2
                    local expanded = _split_multiflag(head)
                    local tail_requires_value = false
                    for (k, f) in enumerate(expanded)
                        if f in flags_need_value
                            if k != length(expanded)
                                _throw_arg_error("Invalid short option bundle: option requiring value must be last in bundle: $tok")
                            end
                            tail_requires_value = true
                        elseif !(f in flags_no_value)
                            if strict_unknown_option
                                return (nothing, 0)
                            end
                        end
                    end
                    if tail_requires_value
                        expecting_value = true
                    end
                    i += 1
                    continue
                end

                if strict_unknown_option
                    return (nothing, 0)
                end

                i += 1
                continue
            end
        else
            if tok in sub_names
                return (tok, i)
            else
                return (nothing, 0)
            end
        end
    end

    return (nothing, 0)
end

function _reject_unknown_option_tokens(args::Vector{String})
    i = 1
    while i <= length(args)
        tok = args[i]
        if tok == "--"
            return
        end
        if _looks_like_flag_token(tok) && !_looks_like_negative_number_token(tok)
            _throw_arg_error("Unknown or unexpected option: $tok")
        end
        i += 1
    end
end

function _build_main_flag_sets(argdefs::Vector{ArgDef})
    flags_need_value = Set{String}()
    flags_no_value = Set{String}()

    for a in argdefs
        if a.kind in (AK_OPTION, AK_OPTION_MULTI)
            for f in a.flags
                push!(flags_need_value, f)
            end
        elseif a.kind in (AK_FLAG, AK_COUNT)
            for f in a.flags
                push!(flags_no_value, f)
            end
        end
    end

    return flags_need_value, flags_no_value
end

function _extract_global_options(
    argv::Vector{String},
    sub_idx::Int,
    flags_need_value::Set{String},
    flags_no_value::Set{String}
)::Tuple{Vector{String},Vector{String}}
    main_tokens = String[]
    sub_tokens = String[]

    i = 1
    passthrough = false

    while i <= length(argv)
        tok = argv[i]

        if i == sub_idx
            i += 1
            continue
        end

        if passthrough
            push!(sub_tokens, tok)
            i += 1
            continue
        end

        if tok == "--"
            push!(sub_tokens, tok)
            passthrough = true
            i += 1
            continue
        end

        if startswith(tok, "-") && tok != "-"
            parts = split(tok, '=', limit=2)
            head = parts[1]
            has_inline_value = (length(parts) == 2)

            if head in flags_need_value
                push!(main_tokens, tok)
                if !has_inline_value
                    i == length(argv) && _throw_arg_error("Option $tok requires a value")
                    nxt = argv[i+1]
                    if nxt == "--"
                        _throw_arg_error("Option $tok requires a value")
                    end
                    push!(main_tokens, nxt)
                    i += 2
                else
                    i += 1
                end
                continue
            elseif head in flags_no_value
                push!(main_tokens, tok)
                i += 1
                continue
            elseif startswith(head, "-") && !startswith(head, "--") && length(head) > 2
                expanded = _split_multiflag(head)
                local all_known = true
                local tail_requires_value = false

                for (k, f) in enumerate(expanded)
                    if f in flags_need_value
                        if k != length(expanded)
                            _throw_arg_error("Invalid short option bundle: option requiring value must be last in bundle: $tok")
                        end
                        tail_requires_value = true
                    elseif f in flags_no_value
                    else
                        all_known = false
                        break
                    end
                end

                if all_known
                    append!(main_tokens, expanded)
                    if tail_requires_value
                        i == length(argv) && _throw_arg_error("Option $(expanded[end]) requires a value")
                        nxt = argv[i+1]
                        if nxt == "--"
                            _throw_arg_error("Option $(expanded[end]) requires a value")
                        end
                        push!(main_tokens, nxt)
                        i += 2
                    else
                        i += 1
                    end
                    continue
                end
            end
        end

        push!(sub_tokens, tok)
        i += 1
    end

    return main_tokens, sub_tokens
end
