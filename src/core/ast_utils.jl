
"""Return a symbol extracted from Symbol/QuoteNode/dotted/quoted AST forms, or `nothing`."""
function extract_macro_symbol(x)::Union{Symbol,Nothing}
    if x isa Symbol
        return x
    elseif x isa QuoteNode && x.value isa Symbol
        return x.value
    elseif x isa Expr
        if x.head == :. && !isempty(x.args)
            return extract_macro_symbol(x.args[end])
        elseif x.head == :quote && length(x.args) == 1
            return extract_macro_symbol(x.args[1])
        end
    end
    return nothing
end

"""Get macro name symbol from a `:macrocall` expression, or `nothing` if not applicable."""
function getmacroname(ex::Expr)::Union{Symbol,Nothing}
    if ex.head != :macrocall || isempty(ex.args)
        return nothing
    end
    sym = extract_macro_symbol(ex.args[1])
    return sym
end

"""Return user arguments of a macro call, excluding macro token and line info."""
@inline function macrocall_user_args(ex::Expr)::Vector{Any}
    if ex.head != :macrocall || length(ex.args) < 3
        return Any[]
    end
    return Any[ex.args[i] for i in 3:length(ex.args)]
end

"""Build `(name, args, node)` info tuple for a macro call, or `nothing`."""
function macrocall_info(ex::Expr)
    name = getmacroname(ex)
    name === nothing && return nothing
    return (name=name, args=macrocall_user_args(ex), node=ex)
end

"""Collect parsed macrocall info objects from a block expression."""
function collect_macrocall_infos(block::Expr)
    infos = Any[]
    for n in getmacrocalls(block)
        info =macrocall_info(n)
        info === nothing || push!(infos, info)
    end
    return infos
end

"""Flatten nested `:block` nodes into a linear node vector, skipping line markers and `nothing`."""
@inline function flatten_block_nodes!(x, out::Vector{Any})
    if x isa LineNumberNode || x === nothing
        return
    elseif x isa Expr && x.head == :block
        for a in x.args
            flatten_block_nodes!(a, out)
        end
    else
        push!(out, x)
    end
end

"""Return an iterator of all macrocall expressions in a block (flattened)."""
function getmacrocalls(block::Expr)
    nodes = Any[]
    flatten_block_nodes!(block, nodes)
    return Iterators.filter(x -> x isa Expr && x.head == :macrocall, nodes)
end

"""Return flattened non-macro nodes from a block."""
function nonmacro_nodes(block::Expr)::Vector{Any}
    nodes = Any[]
    flatten_block_nodes!(block, nodes)

    out = Any[]
    for x in nodes
        if x isa Expr && x.head == :macrocall
            continue
        else
            push!(out, x)
        end
    end
    return out
end

"""Return string literal content from String/QuoteNode, or `nothing`."""
@inline function string_literal_value(x)::Union{String,Nothing}
    if x isa String
        return x
    elseif x isa QuoteNode && x.value isa String
        return x.value
    else
        return nothing
    end
end

"""Parse a keyword-like AST node into `(key, value)`, or return `nothing`."""
@inline function kw_pair(a)::Union{Nothing,Tuple{Any,Any}}
    if a isa Expr
        if (a.head == :(=) || a.head == :kw) && length(a.args) == 2
            return (a.args[1], a.args[2])
        elseif a.head == :parameters
            for x in a.args
                p = kw_pair(x)
                p === nothing || return p
            end
        end
    end
    return nothing
end

"""Extract keyword symbol from Symbol/QuoteNode, or `nothing`."""
@inline function kw_key_symbol(k)::Union{Symbol,Nothing}
    if k isa Symbol
        return k
    elseif k isa QuoteNode && k.value isa Symbol
        return k.value
    else
        return nothing
    end
end

"""Extract and remove `help`/`help_name` keyword metadata from an argument list."""
function extract_help_meta!(
    rest::Vector{Any};
    allow_help_name::Bool=true,
    macro_name::String=""
)::Tuple{String,String}
    _ctx(msg::String) = isempty(macro_name) ? msg : "$(macro_name): " * msg

    help_kw = nothing
    help_name_kw = nothing

    i = 1
    while i <= length(rest)
        a = rest[i]
        local p = kw_pair(a)
        if p !== nothing
            key_raw, rhs = p
            key = kw_key_symbol(key_raw)
            key === nothing && throw(ArgumentError(_ctx("invalid keyword name: $(repr(key_raw))")))

            if key == :help
                rhs_s = string_literal_value(rhs)
                rhs_s === nothing && throw(ArgumentError(_ctx("help keyword accepts only a string literal")))
                help_kw !== nothing && throw(ArgumentError(_ctx("duplicate help keyword provided")))
                help_kw = rhs_s
                deleteat!(rest, i)
                continue
            elseif key == :help_name
                allow_help_name || throw(ArgumentError(_ctx("help_name is not allowed here")))
                rhs_s = string_literal_value(rhs)
                rhs_s === nothing && throw(ArgumentError(_ctx("help_name keyword accepts only a string literal")))
                occursin('\n', rhs_s) && throw(ArgumentError(_ctx("help_name must be single-line text")))
                help_name_kw !== nothing && throw(ArgumentError(_ctx("duplicate help_name keyword provided")))
                help_name_kw = rhs_s
                deleteat!(rest, i)
                continue
            else
                throw(ArgumentError(_ctx("unknown keyword $(key); supported keywords are help=\"...\" and help_name=\"...\"")))
            end
        end
        i += 1
    end

    return (help_kw === nothing ? "" : help_kw,
            help_name_kw === nothing ? "" : help_name_kw)
end
