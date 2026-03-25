function _parse_sub_signature(node::Expr)
    length(node.args) >= 4 || throw(ArgumentError("@CMD_SUB expects \"name\" begin ... end or \"name\" \"desc\" begin ... end"))

    sub_name = node.args[3]
    sub_name isa String || throw(ArgumentError("@CMD_SUB name must be a String literal"))
    startswith(sub_name, "-") && throw(ArgumentError("@CMD_SUB name must not start with '-'"))

    sub_desc = ""
    sub_block = nothing

    if length(node.args) == 4
        sub_block = node.args[4]
    elseif length(node.args) == 5
        if node.args[4] isa String
            sub_desc = node.args[4]
            sub_block = node.args[5]
        else
            throw(ArgumentError("@CMD_SUB second argument must be a String description when 5 arguments are used"))
        end
    else
        throw(ArgumentError("@CMD_SUB expects \"name\" begin ... end or \"name\" \"desc\" begin ... end"))
    end

    (sub_block isa Expr && sub_block.head == :block) || throw(ArgumentError("@CMD_SUB body must be a begin...end block"))
    return sub_name, sub_desc, sub_block
end