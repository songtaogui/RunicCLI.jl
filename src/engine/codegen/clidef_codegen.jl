"""Build code expression for a relation AST node (`RelAll`/`RelAny`/`RelNot`)."""
function build_relation_expr_expr(expr::RelationExpr)
    if expr isa RelAll
        return :($(_gr(:RelAll))(members=$(Expr(:vect, QuoteNode.(expr.members)...))))
    elseif expr isa RelAny
        return :($(_gr(:RelAny))(members=$(Expr(:vect, QuoteNode.(expr.members)...))))
    elseif expr isa RelNot
        return :($(_gr(:RelNot))(inner=$(build_relation_expr_expr(expr.inner))))
    else
        throw(ArgumentError("internal error: unsupported RelationExpr"))
    end
end

"""Build vector expression of runtime `ArgRelationDef` values from relation definitions."""
function build_relations_expr(relation_defs)
    return Expr(:vect, [
        begin
            lhs_expr = rel.lhs === nothing ? :(nothing) : build_relation_expr_expr(rel.lhs)
            rhs_expr = rel.rhs === nothing ? :(nothing) : build_relation_expr_expr(rel.rhs)
            :($(_gr(:ArgRelationDef))(
                kind=$(QuoteNode(rel.kind)),
                lhs=$(lhs_expr),
                rhs=$(rhs_expr),
                members=$(Expr(:vect, QuoteNode.(rel.members)...)),
                help=$(rel.help)
            ))
        end
        for rel in relation_defs
    ]...)
end

"""Build vector expression of runtime `ArgGroupDef` values from group definitions."""
function build_arg_group_defs_expr(arg_group_defs)
    return Expr(:vect, [
        :($(_gr(:ArgGroupDef))(title=$(gd.title), members=$(Expr(:vect, QuoteNode.(gd.members)...))))
        for gd in arg_group_defs
    ]...)
end

"""Emit typed `ArgDef[...]` expression from argument definition expressions."""
function emit_argdefs(argdefs_expr::Vector{Expr})
    return :(ArgDef[$(argdefs_expr...)])
end

"""Build a runtime `CliDef` constructor expression."""
function build_clidef_expr(
    cmd_name_expr, usage_expr, desc_expr, epilog_expr, version_expr,
    args_expr, subcommands_expr, allow_extra, auto_help,
    relation_defs, arg_group_defs
)
    relations_expr = build_relations_expr(relation_defs)
    arg_groups_expr = build_arg_group_defs_expr(arg_group_defs)

    return :($(_gr(:CliDef))(
        cmd_name = $(cmd_name_expr),
        usage = $(usage_expr),
        description = $(desc_expr),
        epilog = $(epilog_expr),
        version = $(version_expr),
        args = $(args_expr),
        subcommands = $(subcommands_expr),
        allow_extra = $(allow_extra),
        auto_help = $(auto_help),
        relations = $(relations_expr),
        arg_groups = $(arg_groups_expr)
    ))
end

"""Build a runtime `SubcommandDef` constructor expression."""
function build_subcommand_def_expr(
    sub_name, sub_desc, sub_usage, sub_epilog, sub_version,
    s_argdefs_expr, sub_allow_extra, sub_auto_help,
    s_relation_defs, s_arg_group_defs
)
    s_relations_expr = build_relations_expr(s_relation_defs)
    s_arg_groups_expr = build_arg_group_defs_expr(s_arg_group_defs)

    return :($(_gr(:SubcommandDef))(
        name=$(sub_name),
        description=$(sub_desc),
        usage=$(sub_usage),
        epilog=$(sub_epilog),
        version=$(sub_version),
        body=nothing,
        args=$(_gr(:ArgDef))[$(s_argdefs_expr...)],
        allow_extra=$(sub_allow_extra),
        auto_help=$(sub_auto_help),
        relations=$(s_relations_expr),
        arg_groups=$(s_arg_groups_expr)
    ))
end
