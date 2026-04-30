"""Validate one CLI flag string format."""
function validate_flag!(f::String, macro_name::String)
    isempty(strip(f)) && throw(ArgumentError("$(macro_name) flag must not be empty"))
    occursin(r"\s", f) && throw(ArgumentError("$(macro_name) flag must not contain whitespace: $(repr(f))"))
    (startswith(f, "-") && f != "-" && f != "--") || throw(ArgumentError("$(macro_name) invalid flag: $(f)"))
    if startswith(f, "-") && !startswith(f, "--") && length(f) != 2
        throw(ArgumentError("$(macro_name) short flag must be exactly one character: $(f)"))
    end
end

"""Register flags to an owner and detect duplicates across declarations."""
function register_flags!(ctx::CompileCtx, flags::Vector{String}, owner::Symbol, macro_name::String)
    for f in flags
        validate_flag!(f, macro_name)
        if haskey(ctx.flag_owner, f)
            throw(ArgumentError("duplicate flag detected: $(f) used by $(ctx.flag_owner[f]) and $(owner)"))
        end
        ctx.flag_owner[f] = owner
    end
end

"""Extract all string flags from remaining declaration arguments."""
function extract_flags!(rest::Vector{Any}, macro_name::String)
    flags = String[]
    for x in rest
        if x isa String
            push!(flags, x)
        elseif x isa QuoteNode && x.value isa String
            push!(flags, x.value)
        else
            throw(ArgumentError("$(macro_name) flags must be String literals; got $(repr(x))"))
        end
    end
    return flags
end

"""Extract declaration keywords (help/env/default/fallback/vfun/vmsg) and remaining positional args."""
function extract_decl_meta!(
    rest::Vector{Any};
    allow_help_name::Bool=true,
    allow_env::Bool=false,
    allow_default::Bool=false,
    allow_fallback::Bool=false,
    macro_name::String=""
)
    help = ""
    help_name = ""
    env_name = nothing
    default_expr = nothing
    fallback_name = nothing
    vfun_expr = nothing
    vmsg_text = ""
    remain = Any[]

    seen_help = false
    seen_help_name = false
    seen_env = false
    seen_default = false
    seen_fallback = false
    seen_vfun = false
    seen_vmsg = false

    for x in rest
        p = kw_pair(x)
        if p === nothing
            push!(remain, x)
            continue
        end

        kraw, v = p
        k = kw_key_symbol(kraw)
        k === nothing && throw(ArgumentError("$(macro_name) invalid keyword name: $(repr(kraw))"))

        if k == :help
            seen_help && throw(ArgumentError("$(macro_name) duplicate keyword: help"))
            s = string_literal_value(v)
            s === nothing && throw(ArgumentError("$(macro_name) help must be a String literal"))
            help = s
            seen_help = true

        elseif k == :help_name
            allow_help_name || throw(ArgumentError("$(macro_name) does not support help_name"))
            seen_help_name && throw(ArgumentError("$(macro_name) duplicate keyword: help_name"))
            s = string_literal_value(v)
            s === nothing && throw(ArgumentError("$(macro_name) help_name must be a String literal"))
            isempty(strip(s)) && throw(ArgumentError("$(macro_name) help_name must not be empty"))
            occursin('\n', s) && throw(ArgumentError("$(macro_name) help_name must be a single-line String (newline is not allowed)"))
            help_name = s
            seen_help_name = true

        elseif k == :env
            allow_env || throw(ArgumentError("$(macro_name) does not support env=\"...\""))
            seen_env && throw(ArgumentError("$(macro_name) duplicate keyword: env"))
            s = string_literal_value(v)
            s === nothing && throw(ArgumentError("$(macro_name) env must be a String literal"))
            isempty(strip(s)) && throw(ArgumentError("$(macro_name) env must not be empty"))
            env_name = s
            seen_env = true

        elseif k == :default
            allow_default || throw(ArgumentError("$(macro_name) does not support default=..."))
            seen_default && throw(ArgumentError("$(macro_name) duplicate keyword: default"))
            default_expr = v
            seen_default = true

        elseif k == :fallback
            allow_fallback || throw(ArgumentError("$(macro_name) does not support fallback=..."))
            seen_fallback && throw(ArgumentError("$(macro_name) duplicate keyword: fallback"))
            fb = _coerce_symbol_identifier(v; allow_wrapped=true)
            fb === nothing && throw(ArgumentError("$(macro_name) fallback must be a Symbol identifier"))
            fallback_name = fb
            seen_fallback = true

        elseif k == :vfun
            seen_vfun && throw(ArgumentError("$(macro_name) duplicate keyword: vfun"))
            vfun_expr = v
            seen_vfun = true

        elseif k == :vmsg
            seen_vmsg && throw(ArgumentError("$(macro_name) duplicate keyword: vmsg"))
            s = string_literal_value(v)
            s === nothing && throw(ArgumentError("$(macro_name) vmsg must be a String literal"))
            vmsg_text = s
            seen_vmsg = true

        else
            throw(ArgumentError("$(macro_name) unknown keyword: $(k)"))
        end
    end

    seen_vmsg && !seen_vfun && throw(ArgumentError("$(macro_name) vmsg requires vfun"))
    seen_vfun || (vmsg_text = "")

    return (
        help=help,
        help_name=help_name,
        env=env_name,
        has_default=seen_default,
        default=default_expr,
        fallback=fallback_name,
        vfun=vfun_expr,
        vmsg=vmsg_text,
        remain=remain
    )
end
