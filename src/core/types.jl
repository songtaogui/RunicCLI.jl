#FILEPATH: ./core/types.jl

"""
    ArgHelpTemplate

`ArgHelpTemplate` defines the rendering callbacks used by `render_help`.

Each field stores a callable (typically a function) responsible for rendering one
logical section of the final help text. The expected callable shape is generally:

`(io, def, path) -> nothing`

where:

- `io` is the target output stream,
- `def` is the current [`CliDef`](@ref) being rendered,
- `path` is the command path string (for nested subcommand help).

You can customize help output by replacing one or more callbacks while keeping the\nothers from `default_help_template` / `colored_help_template`.

# Fields

- `header`:
  Renders the top banner (typically command name and compact usage line).
- `section_usage`:
  Renders explicit usage text if present.
- `section_description`:
  Renders command description text.
- `section_positionals`:
  Renders positional arguments section.
- `section_options`:
  Renders option/flag section.
- `section_subcommands`:
  Renders subcommand list (if any).
- `section_epilog`:
  Renders trailing notes/examples/footer.

# Notes

- `ArgHelpTemplate` is intentionally generic (`{H,U,D,P,O,S,E}`), so each field
  may hold different callable types.
- It is metadata for rendering only; it does not affect parsing semantics.
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

`ArgKind` drives parsing behavior, validation flow, and help rendering style.
Each [`ArgDef`](@ref) stores one `kind::ArgKind`.

# Values

## Option-like kinds

- `AK_FLAG`:
  Boolean switch with no value payload (e.g. `--verbose`).
- `AK_COUNT`:
  Repeatable counter flag; number of appearances becomes an `Int`.
- `AK_OPTION`:
  Single-valued option (`--output file.txt` or `--output=file.txt`).
- `AK_OPTION_MULTI`:
  Repeatable option collecting multiple values into a vector.

## Positional kinds

- `AK_POS_REQUIRED`:
  Required positional argument.
- `AK_POS_DEFAULT`:
  Positional argument with a default when omitted.
- `AK_POS_OPTIONAL`:
  Optional positional argument (typically yields `nothing` when absent).
- `AK_POS_REST`:
  Captures all remaining positional tokens; must be declared last.

# Why this matters

RunicCLI uses `ArgKind` to decide whether an argument:

- consumes a value token,
- may appear multiple times,
- is option-style vs positional-style,
- participates in usage/help sections and parse-order rules.

# See also

[`ArgDef`](@ref), [`CliDef`](@ref), [`SubcommandDef`](@ref)
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

"""
    ArgDef

`ArgDef` describes a single argument in a command schema.

It is the core metadata unit used by parsing, help rendering, source merging
(CLI / environment / config), and runtime validation.

The same structure models both option-style and positional arguments; behavior is
determined primarily by `kind`.

# Fields

- `kind::ArgKind`:
  Semantic argument category.
- `name::Symbol`:
  Logical argument name used internally and in parsed output.
- `T::Any`:
  Target value type for conversion.
- `flags::Vector{String}`:
  Accepted option spellings (for option-like kinds), e.g. `["-o", "--output"]`.
- `default::Any`:
  Default value (used by defaulted declarations).
- `help::String`:
  Human-readable help text.
- `help_name::String`:
  Optional display name override for usage/help rendering.
- `required::Bool`:
  Whether the argument is mandatory under its declaration semantics.

# Notes

- For positional kinds, `flags` is usually empty.
- For `AK_OPTION_MULTI`, parsed value is typically `Vector{T}`.
- Final presence/count semantics used by relation checks (requires/conflicts/groups)
  are computed during parse execution from argument appearances.
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
    ArgRequiresDef

`ArgRequiresDef` declares a dependency relation among option-style arguments.

Rule semantics:

- if `anchor` appears at least once,
- then at least one name in `targets` must also appear.

This metadata is produced from DSL declarations (e.g. `@ARG_REQUIRES`) and
stored on [`CliDef`](@ref) / [`SubcommandDef`](@ref).

# Fields

- `anchor::Symbol`:
  Trigger argument name.
- `targets::Vector{Symbol}`:
  Candidate dependency arguments; at least one must be present when triggered.

# Notes

- `targets` should normally be non-empty.
- Names are expected to reference declared option-like arguments.
"""
Base.@kwdef struct ArgRequiresDef
    anchor::Symbol
    targets::Vector{Symbol} = Symbol[]
end

"""
    ArgConflictsDef

`ArgConflictsDef` declares an incompatibility relation among option-style arguments.

Rule semantics:

- if `anchor` appears at least once,
- then none of the names in `targets` may appear.

This metadata is produced from DSL declarations (e.g. `@ARG_CONFLICTS`) and
stored on [`CliDef`](@ref) / [`SubcommandDef`](@ref).

# Fields

- `anchor::Symbol`:
  Trigger argument name.
- `targets::Vector{Symbol}`:
  Argument names forbidden when `anchor` is present.

# Notes

- `targets` should normally be non-empty.
- Names are expected to reference declared option-like arguments.
"""
Base.@kwdef struct ArgConflictsDef
    anchor::Symbol
    targets::Vector{Symbol} = Symbol[]
end

"""
    SubcommandDef

`SubcommandDef` stores the declarative schema of one subcommand.

It contains command metadata, argument definitions, relation constraints, and
policy flags used by parsing, dispatch, and help rendering.

# Fields

- `name::String`:
  Subcommand token used on CLI (e.g. `"build"`).
- `description::String`:
  One-line summary shown in parent command help.
- `usage::String`:
  Optional explicit usage text for this subcommand.
- `epilog::String`:
  Optional trailing help section text.
- `version::String`:
  Version text returned when `-V` / `--version` is requested in subcommand scope.
- `body::Union{Nothing,Expr}`:
  Optional stored DSL body expression (introspection/compile flow metadata).
- `args::Vector{ArgDef}`:
  Subcommand-local arguments.
- `allow_extra::Bool`:
  Whether unknown leftover tokens are accepted.
- `mutual_exclusion_groups::Vector{Vector{Symbol}}`:
  Groups where at most one argument in each group may be present.
- `mutual_inclusion_groups::Vector{Vector{Symbol}}`:
  Groups where at least one argument in each group must be present.
- `arg_requires::Vector{ArgRequiresDef}`:
  Anchor/targets dependency rules.
- `arg_conflicts::Vector{ArgConflictsDef}`:
  Anchor/targets conflict rules.

# Notes

- `version` enables per-subcommand version messaging in the generated parser flow.
- Subcommand definitions are embedded into `CliDef.subcommands`.
"""
Base.@kwdef struct SubcommandDef
    name::String
    description::String = ""
    usage::String = ""
    epilog::String = ""
    version::String = ""
    body::Union{Nothing,Expr} = nothing
    args::Vector{ArgDef} = ArgDef[]
    allow_extra::Bool = false
    mutual_exclusion_groups::Vector{Vector{Symbol}} = Vector{Vector{Symbol}}()
    mutual_inclusion_groups::Vector{Vector{Symbol}} = Vector{Vector{Symbol}}()
    arg_requires::Vector{ArgRequiresDef} = ArgRequiresDef[]
    arg_conflicts::Vector{ArgConflictsDef} = ArgConflictsDef[]
end

"""
    CliDef

`CliDef` is the top-level declarative schema of a command-line interface.

It combines command metadata, top-level arguments, subcommands, relation rules,
and parser policy options. `CliDef` is used by help rendering, completion
generation, and parser-side introspection.

# Fields

- `cmd_name::String`:
  Command display name.
- `usage::String`:
  Optional explicit usage text.
- `description::String`:
  Main command description.
- `epilog::String`:
  Optional trailing help text.
- `version::String`:
  Version text returned when `-V` / `--version` is requested.
- `args::Vector{ArgDef}`:
  Top-level argument definitions.
- `subcommands::Vector{SubcommandDef}`:
  Declared subcommands.
- `allow_extra::Bool`:
  Whether unknown trailing tokens are allowed.
- `mutual_exclusion_groups::Vector{Vector{Symbol}}`:
  Groups where at most one argument in each group may be present.
- `mutual_inclusion_groups::Vector{Vector{Symbol}}`:
  Groups where at least one argument in each group must be present.
- `arg_requires::Vector{ArgRequiresDef}`:
  Dependency relations.
- `arg_conflicts::Vector{ArgConflictsDef}`:
  Conflict relations.

# Notes

- `CliDef` is schema metadata; actual parsed values are produced by generated
  parser functions / command types.
- This structure is also the input for `render_help` and `generate_completion`.
"""
Base.@kwdef struct CliDef
    cmd_name::String = ""
    usage::String = ""
    description::String = ""
    epilog::String = ""
    version::String = ""
    args::Vector{ArgDef} = ArgDef[]
    subcommands::Vector{SubcommandDef} = SubcommandDef[]
    allow_extra::Bool = false
    mutual_exclusion_groups::Vector{Vector{Symbol}} = Vector{Vector{Symbol}}()
    mutual_inclusion_groups::Vector{Vector{Symbol}} = Vector{Vector{Symbol}}()
    arg_requires::Vector{ArgRequiresDef} = ArgRequiresDef[]
    arg_conflicts::Vector{ArgConflictsDef} = ArgConflictsDef[]
end
