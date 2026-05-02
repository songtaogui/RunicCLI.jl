"""Read a required String literal argument from a macro node at a fixed index."""
function expect_string_literal_at(node::Expr, idx::Int, macro_name::String, expect_ctx::String="")
    length(node.args) >= idx || throw(ArgumentError(
        isempty(expect_ctx) ?
        "$(macro_name) expects one String literal" :
        "$(macro_name) in $(expect_ctx) expects one String literal"
    ))
    v = node.args[idx]

    s = string_literal_value(v)
    s === nothing && throw(ArgumentError(
        isempty(expect_ctx) ?
        "$(macro_name) expects a String literal" :
        "$(macro_name) in $(expect_ctx) expects a String literal"
    ))
    return s
end

"""Parse command-level metadata macros from a block and return normalized meta plus remaining nodes."""
function parse_cmd_meta_block(
    block::Expr;
    initial_desc::String="",
    desc_predeclared::Bool=false,
    dup_ctx::String,
    expect_ctx::String=""
)
    usage = ""
    desc = initial_desc
    epilog = ""
    version = ""
    allow_extra = false
    auto_help = false

    seen_usage = false
    seen_desc = desc_predeclared || !isempty(initial_desc)
    seen_epilog = false
    seen_version = false
    seen_allow = false
    seen_auto_help = false

    other_nodes = Expr[]

    for node in getmacrocalls(block)
        m = getmacroname(node)

        if m == SYM_USAGE
            seen_usage && argerr("@CMD_USAGE is duplicated in $(dup_ctx)")
            usage = expect_string_literal_at(node, 3, "@CMD_USAGE", expect_ctx)
            seen_usage = true

        elseif m == SYM_DESC
            seen_desc && argerr("@CMD_DESC is duplicated in $(dup_ctx)")
            desc = expect_string_literal_at(node, 3, "@CMD_DESC", expect_ctx)
            seen_desc = true

        elseif m == SYM_EPILOG
            seen_epilog && argerr("@CMD_EPILOG is duplicated in $(dup_ctx)")
            epilog = expect_string_literal_at(node, 3, "@CMD_EPILOG", expect_ctx)
            seen_epilog = true

        elseif m == SYM_VERSION
            seen_version && argerr("@CMD_VERSION is duplicated in $(dup_ctx)")
            version = expect_string_literal_at(node, 3, "@CMD_VERSION", expect_ctx)
            seen_version = true

        elseif m == SYM_ALLOW
            seen_allow && argerr("@ALLOW_EXTRA is duplicated in $(dup_ctx)")
            allow_extra = true
            seen_allow = true

        elseif m == SYM_AUTOHELP
            seen_auto_help && argerr("@CMD_AUTOHELP is duplicated in $(dup_ctx)")
            auto_help = true
            seen_auto_help = true

        else
            push!(other_nodes, node)
        end
    end

    return (
        usage=usage,
        desc=desc,
        epilog=epilog,
        version=version,
        allow_extra=allow_extra,
        auto_help=auto_help,
        other_nodes=other_nodes
    )
end
