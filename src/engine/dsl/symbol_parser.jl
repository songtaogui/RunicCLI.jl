
function _coerce_symbol_identifier(x; allow_wrapped::Bool=true)::Union{Symbol,Nothing}
    if x isa Symbol
        return x
    elseif x isa QuoteNode && x.value isa Symbol
        return x.value
    elseif allow_wrapped && x isa Expr
        if x.head == :quote && length(x.args) == 1 && x.args[1] isa Symbol
            return x.args[1]
        elseif x.head in (:global, :local, :const) && length(x.args) == 1 && x.args[1] isa Symbol
            return x.args[1]
        end
    end
    return nothing
end

function _expect_name_symbol(x, macro_name::String, role::String)::Symbol
    s = _coerce_symbol_identifier(x; allow_wrapped=true)
    s !== nothing && return s
    throw(ArgumentError("$(macro_name) $(role) must be a Symbol identifier; got $(repr(x))"))
end

@inline function _collect_symbol_args(node::Expr, start_idx::Int, macro_name::String, role::String)
    syms = Symbol[]
    for i in start_idx:length(node.args)
        push!(syms, _expect_name_symbol(node.args[i], macro_name, role))
    end
    return syms
end

@inline function _ensure_min_count!(syms::Vector{Symbol}, n::Int, macro_name::String, what::String)
    length(syms) >= n || throw(ArgumentError("$(macro_name) requires at least $(n) $(what)"))
end

@inline function _ensure_no_duplicates!(syms::Vector{Symbol}, macro_name::String, what::String)
    length(unique(syms)) == length(syms) || throw(ArgumentError("$(macro_name) contains duplicate $(what)"))
end

function _extract_name_and_rest(node::Expr, name_idx::Int, macro_name::String, role::String)
    x = node.args[name_idx]
    tail = Any[node.args[i] for i in (name_idx + 1):length(node.args)]

    s = _coerce_symbol_identifier(x; allow_wrapped=true)
    if s !== nothing
        return s, tail
    end

    if x isa Expr && x.head in (:global, :local, :const) && length(x.args) == 1
        a = x.args[1]
        if a isa String || (a isa QuoteNode && a.value isa String)
            return Symbol(String(x.head)), Any[a, tail...]
        end
    end

    throw(ArgumentError("$(macro_name) $(role) must be a Symbol identifier; got $(repr(x))"))
end