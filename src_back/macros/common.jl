const _RC = @__MODULE__
_gr(s::Symbol) = GlobalRef(_RC, s)

function _emit_hit_collection_block!(
    out::Vector{Expr},
    syms::Vector{Symbol},
    count_var::Symbol,
    details_var::Symbol;
    increment_count::Bool=true
)
    for s in syms
        nm = string(s)
        push!(out, quote
            local _c = get(_provided_count_map, $(QuoteNode(s)), 0)
            if _c > 0
                $(increment_count ? :($count_var += 1) : :(nothing))
                push!($(details_var), $(nm) * " x" * string(_c))
            end
        end)
    end
    return out
end

function _compile_symbol_group_check(
    groups::Vector{Vector{Symbol}},
    count_condition_builder::Function,
    error_builder::Function
)
    checks = Expr[]
    for grp in groups
        isempty(grp) && continue

        local detail_blocks = Expr[]
        _emit_hit_collection_block!(detail_blocks, grp, :_g_count, :_g_details; increment_count=true)

        push!(checks, quote
            local _g_count = 0
            local _g_details = String[]
            $(detail_blocks...)
            if $(count_condition_builder(:_g_count))
                $(_gr(:_throw_arg_error))($(error_builder(grp, :_g_details)))
            end
        end)
    end
    return checks
end

function _compile_anchor_target_check(
    defs,
    error_condition_builder::Function,
    error_builder::Function;
    count_hits::Bool=true
)
    checks = Expr[]
    for d in defs
        anchor = d.anchor
        targets = d.targets
        isempty(targets) && continue

        local detail_blocks = Expr[]
        _emit_hit_collection_block!(detail_blocks, targets, :_t_count, :_t_details; increment_count=count_hits)

        push!(checks, quote
            local _anchor_count = get(_provided_count_map, $(QuoteNode(anchor)), 0)
            if _anchor_count > 0
                local _t_count = 0
                local _t_details = String[]
                $(detail_blocks...)
                if $(error_condition_builder(:_t_count, :_t_details))
                    $(_gr(:_throw_arg_error))($(error_builder(anchor, targets, :_t_details)))
                end
            end
        end)
    end
    return checks
end

function _compile_group_exclusive_checks(group_defs::Vector{Vector{Symbol}})
    _compile_symbol_group_check(
        group_defs,
        c -> :($c > 1),
        (grp, details) -> :(
            "Mutually exclusive arguments provided together: " *
            join($(string.(grp)), ", ") *
            ". Details: " *
            join($details, "; ")
        )
    )
end

function _compile_group_inclusion_checks(group_defs::Vector{Vector{Symbol}})
    _compile_symbol_group_check(
        group_defs,
        c -> :($c < 1),
        (grp, _) -> :(
            "At least one of the following arguments must be provided: " *
            join($(string.(grp)), ", ")
        )
    )
end

function _compile_arg_requires_checks(req_defs)
    _compile_anchor_target_check(
        req_defs,
        (c, _) -> :($c < 1),
        (anchor, targets, _) -> :(
            "Argument " * $(string(anchor)) * " requires at least one of: " * join($(string.(targets)), ", ")
        );
        count_hits=true
    )
end

function _compile_arg_conflicts_checks(conf_defs)
    _compile_anchor_target_check(
        conf_defs,
        (_, details) -> :(!isempty($details)),
        (anchor, _, details) -> :(
            "Argument " * $(string(anchor)) * " conflicts with: " * join($details, ", ")
        );
        count_hits=false
    )
end


function _compile_leftover_policy(allow_extra::Bool)
    if allow_extra
        return :(nothing)
    else
        return quote
            if !isempty(_args)
                local _hint = any($(_gr(:_looks_like_negative_number_token)), _args) ? " Hint: pass positional negative numbers after '--' (e.g. -- -1)." : ""
                $(_gr(:_throw_arg_error))("Unknown or unexpected arguments: " * join(_args, " ") * _hint)
            end
        end
    end
end

function _emit_constraint_vector_expr(groups::Vector{Vector{Symbol}})
    Expr(:vect, [Expr(:vect, QuoteNode.(g)...) for g in groups]...)
end

function _emit_arg_requires_vector_expr(req_defs::Vector{ArgRequiresDef})
    Expr(:vect, [
        :($(_gr(:ArgRequiresDef))(anchor=$(QuoteNode(rd.anchor)), targets=$(Expr(:vect, QuoteNode.(rd.targets)...))))
        for rd in req_defs
    ]...)
end

function _emit_arg_conflicts_vector_expr(conf_defs::Vector{ArgConflictsDef})
    Expr(:vect, [
        :($(_gr(:ArgConflictsDef))(anchor=$(QuoteNode(cd.anchor)), targets=$(Expr(:vect, QuoteNode.(cd.targets)...))))
        for cd in conf_defs
    ]...)
end

function _emit_constraint_exprs(spec)
    return (
        _emit_constraint_vector_expr(spec.mutual_exclusion_groups),
        _emit_constraint_vector_expr(spec.mutual_inclusion_groups),
        _emit_arg_requires_vector_expr(spec.arg_requires),
        _emit_arg_conflicts_vector_expr(spec.arg_conflicts),
    )
end

function _emit_namedtuple_literal(names::Vector{Symbol})
    return :( (; $(names...)) )
end

function _emit_clidef_expr(
    cmd_name_expr,
    usage,
    description,
    epilog,
    args_expr,
    subcommands_expr,
    allow_extra,
    excl_expr,
    incl_expr,
    arg_requires_expr,
    arg_conflicts_expr
)
    return :($(_gr(:CliDef))(
        cmd_name = $(cmd_name_expr),
        usage = $(usage),
        description = $(description),
        epilog = $(epilog),
        args = $(args_expr),
        subcommands = $(subcommands_expr),
        allow_extra = $(allow_extra),
        mutual_exclusion_groups = $(excl_expr),
        mutual_inclusion_groups = $(incl_expr),
        arg_requires = $(arg_requires_expr),
        arg_conflicts = $(arg_conflicts_expr)
    ))
end
