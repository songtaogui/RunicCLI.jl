
function _expect_string_literal_at(node::Expr, idx::Int, macro_name::String, expect_ctx::String="")
    length(node.args) >= idx || throw(ArgumentError(
        isempty(expect_ctx) ?
        "$(macro_name) expects one String literal" :
        "$(macro_name) in $(expect_ctx) expects one String literal"
    ))
    v = node.args[idx]

    s = _string_literal_value(v)
    s === nothing && throw(ArgumentError(
        isempty(expect_ctx) ?
        "$(macro_name) expects a String literal" :
        "$(macro_name) in $(expect_ctx) expects a String literal"
    ))
    return s
end


function _parse_cmd_meta_block(
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

    seen_usage = false
    seen_desc = desc_predeclared || !isempty(initial_desc)
    seen_epilog = false
    seen_version = false
    seen_allow = false

    other_nodes = Expr[]

    for node in _getmacrocalls(block)
        m = _getmacroname(node)

        if m == SYM_USAGE
            seen_usage && throw(ArgumentError("@CMD_USAGE is duplicated in $(dup_ctx)"))
            usage = _expect_string_literal_at(node, 3, "@CMD_USAGE", expect_ctx)
            seen_usage = true

        elseif m == SYM_DESC
            seen_desc && throw(ArgumentError("@CMD_DESC is duplicated in $(dup_ctx)"))
            desc = _expect_string_literal_at(node, 3, "@CMD_DESC", expect_ctx)
            seen_desc = true

        elseif m == SYM_EPILOG
            seen_epilog && throw(ArgumentError("@CMD_EPILOG is duplicated in $(dup_ctx)"))
            epilog = _expect_string_literal_at(node, 3, "@CMD_EPILOG", expect_ctx)
            seen_epilog = true

        elseif m == SYM_VERSION
            seen_version && throw(ArgumentError("@CMD_VERSION is duplicated in $(dup_ctx)"))
            version = _expect_string_literal_at(node, 3, "@CMD_VERSION", expect_ctx)
            seen_version = true

        elseif m == SYM_ALLOW
            seen_allow && throw(ArgumentError("@ALLOW_EXTRA is duplicated in $(dup_ctx)"))
            allow_extra = true
            seen_allow = true

        else
            push!(other_nodes, node)
        end
    end

    return (usage=usage, desc=desc, epilog=epilog, version=version, allow_extra=allow_extra, other_nodes=other_nodes)
end
