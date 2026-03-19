struct ArgParseError <: Exception
    message::String
end

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