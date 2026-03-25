
function _build_relation_defs_exprs(gdefs_excl, gdefs_incl, arg_requires_defs, arg_conflicts_defs)
    excl_expr = Expr(:vect, [Expr(:vect, QuoteNode.(g)...) for g in gdefs_excl]...)
    incl_expr = Expr(:vect, [Expr(:vect, QuoteNode.(g)...) for g in gdefs_incl]...)

    req_expr = Expr(:vect, [
        :($(_gr(:ArgRequiresDef))(anchor=$(QuoteNode(rd.anchor)), targets=$(Expr(:vect, QuoteNode.(rd.targets)...))))
        for rd in arg_requires_defs
    ]...)

    conf_expr = Expr(:vect, [
        :($(_gr(:ArgConflictsDef))(anchor=$(QuoteNode(cd.anchor)), targets=$(Expr(:vect, QuoteNode.(cd.targets)...))))
        for cd in arg_conflicts_defs
    ]...)

    return excl_expr, incl_expr, req_expr, conf_expr
end


function _emit_argdefs(argdefs_expr::Vector{Expr})
    return :(ArgDef[$(argdefs_expr...)])
end

function _build_clidef_expr(cmd_name_expr, usage_expr, desc_expr, epilog_expr, version_expr, args_expr, subcommands_expr, allow_extra, gdefs_excl, gdefs_incl, arg_requires_defs, arg_conflicts_defs)
    excl_expr, incl_expr, req_expr, conf_expr = _build_relation_defs_exprs(gdefs_excl, gdefs_incl, arg_requires_defs, arg_conflicts_defs)

    return :($(_gr(:CliDef))(
        cmd_name = $(cmd_name_expr),
        usage = $(usage_expr),
        description = $(desc_expr),
        epilog = $(epilog_expr),
        version = $(version_expr),
        args = $(args_expr),
        subcommands = $(subcommands_expr),
        allow_extra = $(allow_extra),
        mutual_exclusion_groups = $(excl_expr),
        mutual_inclusion_groups = $(incl_expr),
        arg_requires = $(req_expr),
        arg_conflicts = $(conf_expr)
    ))
end

function _build_subcommand_def_expr(
    sub_name, sub_desc, sub_usage, sub_epilog, sub_version,
    s_argdefs_expr, sub_allow_extra,
    s_gdefs_excl, s_gdefs_incl, s_arg_requires_defs, s_arg_conflicts_defs
)
    s_excl_expr, s_incl_expr, s_req_expr, s_conf_expr =
        _build_relation_defs_exprs(s_gdefs_excl, s_gdefs_incl, s_arg_requires_defs, s_arg_conflicts_defs)

    return :($(_gr(:SubcommandDef))(
        name=$(sub_name),
        description=$(sub_desc),
        usage=$(sub_usage),
        epilog=$(sub_epilog),
        version=$(sub_version),
        body=nothing,
        args=$(_gr(:ArgDef))[$(s_argdefs_expr...)],
        allow_extra=$(sub_allow_extra),
        mutual_exclusion_groups=$(s_excl_expr),
        mutual_inclusion_groups=$(s_incl_expr),
        arg_requires=$(s_req_expr),
        arg_conflicts=$(s_conf_expr)
    ))
end
