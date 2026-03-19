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

"""
    ArgKind

Enumeration describing the semantic kind of a declared CLI argument.

`ArgKind` is used internally by RunicCLI to distinguish among option-style arguments, flags, counters,
and positional arguments. It influences parsing behavior, help formatting, validation rules,
auto-generated usage fallback text, and rendering emphasis.

Every [`ArgDef`](@ref) stores a `kind::ArgKind`.

# Values

## Option-style arguments

- `AK_FLAG`  
  Boolean switch with no value payload. Produced by `@ARG_FLAG`.

- `AK_COUNT`  
  Repeatable counting flag. The number of occurrences becomes an `Int`. Produced by `@ARG_COUNT`.

- `AK_OPTION`  
  Single-valued option. This includes required options, optional options, and default-valued options
  depending on the declaration form (`@ARG_REQ`, `@ARG_OPT`, `@ARG_DEF`).

- `AK_OPTION_MULTI`  
  Repeatable option collecting multiple values into a vector. Produced by `@ARG_MULTI`.

## Positional arguments

- `AK_POS_REQUIRED`  
  Required positional argument. Produced by `@POS_REQ`.

- `AK_POS_DEFAULT`  
  Positional argument with a default value if omitted. Produced by `@POS_DEF`.

- `AK_POS_OPTIONAL`  
  Optional positional argument yielding `nothing` if omitted. Produced by `@POS_OPT`.

- `AK_POS_REST`  
  Collects all remaining positional tokens into a vector. Produced by `@POS_REST`.
  Only one is allowed, and it must be declared last.

# Why `ArgKind` matters

RunicCLI uses `ArgKind` to decide, among other things:

- whether an argument consumes a value,
- whether multiple occurrences are allowed,
- whether a positional can be omitted,
- how help specs are displayed,
- whether a declaration contributes to the options section or the positionals section,
- whether an argument can participate in mutual exclusion groups.

For example:

- `AK_FLAG` renders as a flag spec with no metavar and parses to `Bool`,
- `AK_OPTION_MULTI` renders with a metavar and parses to `Vector{T}`,
- `AK_POS_REST` renders as a repeated positional and consumes all trailing tokens.

# Notes

- `AK_OPTION` covers several declaration forms that differ by requiredness/default semantics.
  Those distinctions are represented by additional fields on [`ArgDef`](@ref), such as `required`
  and `default`, not by separate enum values.
- Mutual exclusion groups only support option-style arguments, not positional kinds.

# See also

[`ArgDef`](@ref), [`@CMD_MAIN`](@ref), [`render_help`](@ref)
"""
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

@inline _is_option_kind(k::ArgKind) = k in (AK_FLAG, AK_COUNT, AK_OPTION, AK_OPTION_MULTI)
@inline _is_positional_kind(k::ArgKind) = k in (AK_POS_REQUIRED, AK_POS_DEFAULT, AK_POS_OPTIONAL, AK_POS_REST)
@inline _is_option_value_kind(k::ArgKind) = k in (AK_OPTION, AK_OPTION_MULTI)
@inline _is_option_scalar_kind(k::ArgKind) = k == AK_OPTION
@inline _is_option_multi_kind(k::ArgKind) = k == AK_OPTION_MULTI
@inline _is_flag_kind(k::ArgKind) = k == AK_FLAG
@inline _is_count_kind(k::ArgKind) = k == AK_COUNT
@inline _is_pos_required_kind(k::ArgKind) = k == AK_POS_REQUIRED
@inline _is_pos_default_kind(k::ArgKind) = k == AK_POS_DEFAULT
@inline _is_pos_optional_kind(k::ArgKind) = k == AK_POS_OPTIONAL
@inline _is_pos_rest_kind(k::ArgKind) = k == AK_POS_REST

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

Base.@kwdef struct ArgRequiresDef
    anchor::Symbol
    targets::Vector{Symbol} = Symbol[]
end

Base.@kwdef struct ArgConflictsDef
    anchor::Symbol
    targets::Vector{Symbol} = Symbol[]
end


"""
`SubcommandDef` stores metadata for a subcommand.

# Fields
- `name`: subcommand token as typed on CLI.
- `description`: one-line description for help listing.
- `body`: original DSL expression block.
- `args`: argument definitions specific to this subcommand.
- `allow_extra`: whether unknown trailing tokens are allowed.
- `mutual_exclusion_groups`: argument-name groups where at most one may be present.
- `mutual_inclusion_groups`: argument-name groups where at least one may be present.

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
    mutual_inclusion_groups::Vector{Vector{Symbol}} = Vector{Vector{Symbol}}()
    arg_requires::Vector{ArgRequiresDef} = ArgRequiresDef[]
    arg_conflicts::Vector{ArgConflictsDef} = ArgConflictsDef[]
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
- `mutual_inclusion_groups`: argument-name groups where at least one may be present.

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
    mutual_inclusion_groups::Vector{Vector{Symbol}} = Vector{Vector{Symbol}}()
    arg_requires::Vector{ArgRequiresDef} = ArgRequiresDef[]
    arg_conflicts::Vector{ArgConflictsDef} = ArgConflictsDef[]
end

Base.@kwdef struct NormalizedArgSpec
    kind::ArgKind
    name::Symbol
    T::Any = Any
    flags::Vector{String} = String[]
    default::Any = nothing
    help::String = ""
    help_name::String = ""
    required::Bool = false
    validator::Any = nothing
    validator_message::String = ""
    validator_mode::Symbol = :none   # :none | :test | :stream
end

Base.@kwdef struct NormalizedCmdSpec
    args::Vector{NormalizedArgSpec} = NormalizedArgSpec[]
    mutual_exclusion_groups::Vector{Vector{Symbol}} = Vector{Vector{Symbol}}()
    mutual_inclusion_groups::Vector{Vector{Symbol}} = Vector{Vector{Symbol}}()
    arg_requires::Vector{ArgRequiresDef} = ArgRequiresDef[]
    arg_conflicts::Vector{ArgConflictsDef} = ArgConflictsDef[]
end

Base.@kwdef struct NormalizedCmdMeta
    usage::String = ""
    description::String = ""
    epilog::String = ""
    allow_extra::Bool = false
end
