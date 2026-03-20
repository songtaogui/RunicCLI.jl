"""
    load_config_file(path::AbstractString) -> Dict{String,Any}

Load a configuration file into a string-keyed dictionary.

Supported extensions:
- `.toml`  (via `TOML.parsefile`, built-in)
- `.json`  (requires `JSON3.jl`)
- `.yaml` / `.yml` (requires `YAML.jl`)

Behavior:
- Keys are normalized to `String`.
- Returns `Dict{String,Any}`.
- Throws `ArgParseError` for unsupported extensions or missing optional parser packages.

This function is used by generated `@CMD_MAIN` constructors when `config_file=...` is passed.
See also [`merge_cli_sources`](@ref) for how loaded values are translated into CLI tokens.
"""
function load_config_file(path::AbstractString)::Dict{String,Any}
    ext = lowercase(splitext(String(path))[2])
    if ext == ".toml"
        return Dict{String,Any}(string(k)=>v for (k,v) in pairs(TOML.parsefile(path)))
    elseif ext == ".json"
        if Base.find_package("JSON3") === nothing
            _throw_arg_error("JSON config requires JSON3.jl")
        end
        JSON3 = Base.require(Base.PkgId(Base.UUID("0f8b85d8-7281-11e9-16c6-ff7f4f0f5f3b"), "JSON3"))
        obj = JSON3.read(read(path, String))
        return Dict{String,Any}(string(k)=>v for (k,v) in pairs(obj))
    elseif ext in (".yaml", ".yml")
        if Base.find_package("YAML") === nothing
            _throw_arg_error("YAML config requires YAML.jl")
        end
        YAML = Base.require(Base.PkgId(Base.UUID("ddb6d928-2868-570f-bddf-ab3f9cf99eb6"), "YAML"))
        obj = YAML.load_file(path)
        return Dict{String,Any}(string(k)=>v for (k,v) in pairs(obj))
    else
        _throw_arg_error("Unsupported config file extension: $(ext)")
    end
end

_env_key(name::Symbol, env_prefix::String) = uppercase(env_prefix * string(name))


function _arg_present_cli(argv::Vector{String}, a::ArgDef)::Bool
    toks = _split_arguments(copy(argv))
    dd = findfirst(==("--"), toks)
    pre = isnothing(dd) ? toks : toks[1:dd-1]

    if a.kind in (AK_OPTION, AK_OPTION_MULTI, AK_FLAG, AK_COUNT)
        any(t -> t in a.flags, pre)
    else
        false
    end
end

function _get_cfg(cfg::AbstractDict, name::Symbol)
    haskey(cfg, string(name)) && return cfg[string(name)]
    haskey(cfg, name) && return cfg[name]
    return nothing
end

function _append_option_tokens!(out::Vector{String}, a::ArgDef, v)
    f = isempty(a.flags) ? "" : a.flags[end]
    if a.kind == AK_FLAG
        Bool(v) && push!(out, f)
    elseif a.kind == AK_COUNT
        n = Int(v)
        for _ in 1:max(0, n)
            push!(out, f)
        end
    elseif a.kind == AK_OPTION
        push!(out, f); push!(out, string(v))
    elseif a.kind == AK_OPTION_MULTI
        if v isa AbstractVector
            for x in v
                push!(out, f); push!(out, string(x))
            end
        else
            push!(out, f); push!(out, string(v))
        end
    end
end

"""
    merge_cli_sources(
        argv::Vector{String},
        argdefs::Vector{ArgDef};
        env_prefix::String="",
        env::AbstractDict=ENV,
        config::AbstractDict=Dict{String,Any}()
    ) -> Vector{String}

Merge CLI arguments with config/environment fallback sources and return a new argv vector.

Purpose:
- Preserve explicit CLI input as highest priority.
- Fill missing option-style arguments from config/env.
- Optionally append positional fallback values (after `--`) from config/env.

Rules (current implementation):
1. Start from a copy of `argv`.
2. For each option-style argument (`AK_OPTION`, `AK_OPTION_MULTI`, `AK_FLAG`, `AK_COUNT`):
   - if already present in CLI, keep CLI value;
   - else use `config[name]` (or `config[string(name)]`) if present;
   - else use env key `uppercase(env_prefix * string(name))` if present.
3. For positional argument defs (`AK_POS_REQUIRED`, `AK_POS_DEFAULT`, `AK_POS_OPTIONAL`, `AK_POS_REST`):
   - if any positional defs exist, append `--`,
   - then append fallback positional values from config/env in declaration order.

Notes:
- This function only produces tokens; normal parsing/validation still happens later.
- For `AK_OPTION_MULTI`, scalar config/env values are accepted as one occurrence; vectors expand to repeated flag-value pairs.
- For `AK_COUNT`, integer-like source values expand to repeated count flags.

Used internally by generated `@CMD_MAIN` constructors and available for advanced/custom workflows.
"""
function merge_cli_sources(
    argv::Vector{String},
    argdefs::Vector{ArgDef};
    env_prefix::String="",
    env::AbstractDict=ENV,
    config::AbstractDict=Dict{String,Any}()
)::Vector{String}
    out = copy(argv)

    for a in argdefs
        if a.kind in (AK_OPTION, AK_OPTION_MULTI, AK_FLAG, AK_COUNT)
            _arg_present_cli(out, a) && continue

            cv = _get_cfg(config, a.name)
            if cv !== nothing
                _append_option_tokens!(out, a, cv)
                continue
            end

            ek = _env_key(a.name, env_prefix)
            if haskey(env, ek)
                _append_option_tokens!(out, a, env[ek])
            end
        end
    end

    posdefs = [a for a in argdefs if a.kind in (AK_POS_REQUIRED, AK_POS_DEFAULT, AK_POS_OPTIONAL, AK_POS_REST)]
    if !isempty(posdefs)
        push!(out, "--")
        for a in posdefs
            cv = _get_cfg(config, a.name)
            if cv === nothing
                ek = _env_key(a.name, env_prefix)
                cv = haskey(env, ek) ? env[ek] : nothing
            end
            cv === nothing && continue

            if a.kind == AK_POS_REST && cv isa AbstractVector
                append!(out, string.(cv))
            else
                push!(out, string(cv))
            end
        end
    end

    return out
end
