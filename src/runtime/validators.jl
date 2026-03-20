v_min(minv) = x -> x >= minv
v_max(maxv) = x -> x <= maxv
v_range(lo, hi; closed::Bool=true) = closed ? (x -> lo <= x <= hi) : (x -> lo < x < hi)

v_oneof(xs) = begin
    s = Set(xs)
    x -> x in s
end

v_include(xs) = v_oneof(xs)
v_exclude(xs) = begin
    s = Set(xs)
    x -> !(x in s)
end

function v_length(; min::Union{Nothing,Int}=nothing, max::Union{Nothing,Int}=nothing, eq::Union{Nothing,Int}=nothing)
    return x -> begin
        n = length(x)
        if eq !== nothing
            n == eq
        else
            (min === nothing || n >= min) && (max === nothing || n <= max)
        end
    end
end

v_prefix(p::AbstractString) = x -> startswith(String(x), p)
v_suffix(s::AbstractString) = x -> endswith(String(x), s)

function v_regex(re::Regex)
    x -> occursin(re, String(x))
end

v_exists() = x -> ispath(String(x))
v_isfile() = x -> isfile(String(x))
v_isdir() = x -> isdir(String(x))
v_readable() = x -> isreadable(String(x))
v_writable() = x -> iswritable(String(x))

function v_and(fs::Function...)
    x -> begin
        for f in fs
            f(x) || return false
        end
        true
    end
end

function v_or(fs::Function...)
    x -> begin
        for f in fs
            f(x) && return true
        end
        false
    end
end
