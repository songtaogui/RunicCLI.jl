
"""
`ArgParseError(message)` represents a user-facing command-line parsing failure.

This exception is thrown when required arguments are missing, values cannot be
parsed into the expected type, mutually exclusive arguments are violated, or
unknown/extra arguments are encountered (depending on parser configuration).

The `message` field should be safe to display directly to end users.
"""
struct ArgParseError <: Exception
    message::String
end


"""
`ArgHelpRequested(message)` is a control-flow exception used to indicate that
help text has been printed (or should be printed) and normal execution should stop.

This is not a parsing failure. Applications typically catch this exception and
exit successfully (often with exit code `0`).
"""
struct ArgHelpRequested <: Exception
    def::CliDef
    path::String
    message::String
end
ArgHelpRequested(def::CliDef, path::String="") = ArgHelpRequested(def, path, "")
ArgHelpRequested(message::String) = ArgHelpRequested(CliDef(), "", message)

Base.showerror(io::IO, e::ArgParseError) = print(io, "Argument parsing error: ", e.message)

function Base.showerror(io::IO, e::ArgHelpRequested)
    if !isempty(e.message)
        print(io, e.message)
    elseif !isempty(e.path) || !isempty(e.def.cmd_name) || !isempty(e.def.args) || !isempty(e.def.subcommands)
        print(io, render_help(e.def; path=e.path))
    end
end
