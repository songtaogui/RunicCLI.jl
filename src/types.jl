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
    message::String
end


"""
`ArgHelpTemplate` defines the rendering callbacks used by `render_help`.

Each field is a function `(io, def, path) -> nothing` responsible for rendering
one section of the final help message.

# Fields
- `header`: top usage line(s).
- `section_usage`: optional explicit usage section.
- `section_description`: command description.
- `section_positionals`: positional argument list.
- `section_options`: option/flag list.
- `section_subcommands`: subcommand list.
- `section_epilog`: trailing notes/examples.

Custom templates can be built by replacing any callback while reusing defaults
for other sections.
"""
Base.@kwdef struct ArgHelpTemplate{H,U,D,P,O,S,E}
    header::H
    section_usage::U
    section_description::D
    section_positionals::P
    section_options::O
    section_subcommands::S
    section_epilog::E
end


@enum ArgKind begin
    AK_FLAG
    AK_COUNT
    AK_OPTION
    AK_OPTION_MULTI
    AK_POS_REQUIRED
    AK_POS_DEFAULT
    AK_POS_OPTIONAL
    AK_POS_REST
end

"""
`ArgDef` describes one command-line argument in a schema.

It is used for help rendering and parser metadata. Depending on `kind`, the same
structure models flags, options, and positional arguments.

# Key fields
- `kind::ArgKind`: argument category.
- `name::Symbol`: logical field name in parsed output.
- `T`: expected Julia type for parsed values.
- `flags::Vector{String}`: accepted option spellings (e.g. `["-o", "--output"]`).
- `default`: default value for defaulted arguments.
- `help`: human-readable help text.
- `help_name`: display name override used in help output.
- `required::Bool`: whether the argument is mandatory.

Additional metadata fields (`tests`, `stream_validator`, `group`) can be used
for validation and grouping semantics.
"""
Base.@kwdef struct ArgDef
    kind::ArgKind
    name::Symbol
    T::Any
    flags::Vector{String} = String[]
    default::Any = nothing
    help::String = ""
    help_name::String = ""
    required::Bool = false
end

"""
`SubcommandDef` stores metadata for a subcommand.

# Fields
- `name`: subcommand token as typed on CLI.
- `description`: one-line description for help listing.
- `body`: original DSL expression block.
- `args`: argument definitions specific to this subcommand.

Instances are embedded in `CliDef.subcommands` and consumed by help rendering
and dispatch logic.
"""
Base.@kwdef struct SubcommandDef
    name::String
    description::String = ""
    usage::String = ""
    epilog::String = ""
    body::Union{Nothing,Expr} = nothing
    args::Vector{ArgDef} = ArgDef[]
    allow_extra::Bool = false
    mutual_exclusion_groups::Vector{Vector{Symbol}} = Vector{Vector{Symbol}}()
end


"""
`CliDef` is the full declarative schema of a command parser.

It combines top-level command metadata (`cmd_name`, `usage`, `description`,
`epilog`) with argument definitions, subcommand definitions, and policy flags.

# Fields
- `args`: top-level arguments (`Vector{ArgDef}`).
- `subcommands`: available subcommands (`Vector{SubcommandDef}`).
- `allow_extra`: whether unknown trailing tokens are allowed.
- `mutual_exclusion_groups`: argument-name groups where at most one may be present.

`CliDef` is primarily used for help generation and parser introspection.
"""
Base.@kwdef struct CliDef
    cmd_name::String = ""
    usage::String = ""
    description::String = ""
    epilog::String = ""
    args::Vector{ArgDef} = ArgDef[]
    subcommands::Vector{SubcommandDef} = SubcommandDef[]
    allow_extra::Bool = false
    mutual_exclusion_groups::Vector{Vector{Symbol}} = Vector{Vector{Symbol}}()
end
