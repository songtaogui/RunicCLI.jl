# RunicCLI
# ast_utils.jl

const SYM_USAGE   = Symbol("@CMD_USAGE")
const SYM_DESC    = Symbol("@CMD_DESC")
const SYM_EPILOG  = Symbol("@CMD_EPILOG")
const SYM_SUB     = Symbol("@CMD_SUB")
const SYM_TEST    = Symbol("@ARG_TEST")
const SYM_STREAM  = Symbol("@ARG_STREAM")

const SYM_GROUP   = Symbol("@GROUP_EXCL")
const SYM_GROUP_INCL = Symbol("@GROUP_INCL")
const SYM_ARG_REQUIRES = Symbol("@ARG_REQUIRES")
const SYM_ARG_CONFLICTS = Symbol("@ARG_CONFLICTS")
const SYM_ALLOW   = Symbol("@ALLOW_EXTRA")

const SYM_REQ     = Symbol("@ARG_REQ")
const SYM_DEF     = Symbol("@ARG_DEF")
const SYM_OPT     = Symbol("@ARG_OPT")
const SYM_FLAG    = Symbol("@ARG_FLAG")
const SYM_COUNT   = Symbol("@ARG_COUNT")
const SYM_MULTI   = Symbol("@ARG_MULTI")

const SYM_POS_REQ = Symbol("@POS_REQ")
const SYM_POS_DEF = Symbol("@POS_DEF")
const SYM_POS_OPT = Symbol("@POS_OPT")
const SYM_POS_RST = Symbol("@POS_REST")

"""
    _extract_macro_symbol(x) -> Union{Symbol,Nothing}

Try to normalize macro head into a Symbol, supporting both:

- Symbol("@ARG_REQ")
- Expr(:., mod, QuoteNode(Symbol("@ARG_REQ")))
- nested dotted forms
"""
function _extract_macro_symbol(x)::Union{Symbol,Nothing}
    if x isa Symbol
        return x
    elseif x isa QuoteNode && x.value isa Symbol
        return x.value
    elseif x isa Expr
        if x.head == :. && !isempty(x.args)
            return _extract_macro_symbol(x.args[end])
        elseif x.head == :quote && length(x.args) == 1
            return _extract_macro_symbol(x.args[1])
        end
    end
    return nothing
end


"""
    _getmacroname(ex::Expr) -> Union{Symbol,Nothing}

Robust macro name extractor.
Returns `nothing` when extraction fails.
"""
function _getmacroname(ex::Expr)::Union{Symbol,Nothing}
    if ex.head != :macrocall || isempty(ex.args)
        return nothing
    end
    sym = _extract_macro_symbol(ex.args[1])
    return sym
end

@inline function _flatten_block_nodes!(x, out::Vector{Any})
    if x isa LineNumberNode || x === nothing
        return
    elseif x isa Expr && x.head == :block
        for a in x.args
            _flatten_block_nodes!(a, out)
        end
    else
        push!(out, x)
    end
end

"""
    _getmacrocalls(block::Expr)

Return all macrocall nodes from a block-like expression.
Nested `begin ... end` blocks are flattened recursively.
"""
function _getmacrocalls(block::Expr)
    nodes = Any[]
    _flatten_block_nodes!(block, nodes)
    return Iterators.filter(x -> x isa Expr && x.head == :macrocall, nodes)
end

"""
    _nonmacro_nodes(block::Expr) -> Vector{Any}

Collect non-macro statements in a block-like expression.
Nested blocks are flattened recursively.
"""
function _nonmacro_nodes(block::Expr)::Vector{Any}
    nodes = Any[]
    _flatten_block_nodes!(block, nodes)

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

@inline function _string_literal_value(x)::Union{String,Nothing}
    if x isa String
        return x
    elseif x isa QuoteNode && x.value isa String
        return x.value
    else
        return nothing
    end
end

@inline function _kw_pair(a)::Union{Nothing,Tuple{Any,Any}}
    if a isa Expr
        if (a.head == :(=) || a.head == :kw) && length(a.args) == 2
            return (a.args[1], a.args[2])
        elseif a.head == :parameters
            for x in a.args
                p = _kw_pair(x)
                p === nothing || return p
            end
        end
    end
    return nothing
end

@inline function _kw_key_symbol(k)::Union{Symbol,Nothing}
    if k isa Symbol
        return k
    elseif k isa QuoteNode && k.value isa Symbol
        return k.value
    else
        return nothing
    end
end

@inline function _unsupported_help_meta_keyword_error(ctx::String, key)
    throw(ArgumentError(ctx * "unknown keyword $(key); supported keywords are help=\"...\" and help_name=\"...\""))
end

function _extract_help_meta!(
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
        local p = _kw_pair(a)
        if p !== nothing
            key_raw, rhs = p
            key = _kw_key_symbol(key_raw)
            key === nothing && throw(ArgumentError(_ctx("invalid keyword name: $(repr(key_raw))")))

            if key == :help
                rhs_s = _string_literal_value(rhs)
                rhs_s === nothing && throw(ArgumentError(_ctx("help keyword accepts only a string literal")))
                help_kw !== nothing && throw(ArgumentError(_ctx("duplicate help keyword provided")))
                help_kw = rhs_s
                deleteat!(rest, i)
                continue
            elseif key == :help_name
                allow_help_name || throw(ArgumentError(_ctx("help_name is not allowed here")))
                rhs_s = _string_literal_value(rhs)
                rhs_s === nothing && throw(ArgumentError(_ctx("help_name keyword accepts only a string literal")))
                occursin('\n', rhs_s) && throw(ArgumentError(_ctx("help_name must be single-line text")))
                help_name_kw !== nothing && throw(ArgumentError(_ctx("duplicate help_name keyword provided")))
                help_name_kw = rhs_s
                deleteat!(rest, i)
                continue
            else
                _unsupported_help_meta_keyword_error(_ctx(""), key)
            end
        end
        i += 1
    end

    return (help_kw === nothing ? "" : help_kw,
            help_name_kw === nothing ? "" : help_name_kw)
end



