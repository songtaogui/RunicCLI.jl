"""
`RunicCLI` is a macro-driven command-line parsing framework for Julia.

The package provides a declarative DSL to define command schemas (options,
flags, positional arguments, validators, and subcommands) and compiles them
into strongly typed parser constructors.

# Main features
- Declarative parser definition with macros (`@CMD_MAIN`, `@CMD_SUB`, `@ARG_*`, `@POS_*`).
- Typed parse results stored in generated structs.
- Built-in help generation with customizable templates.
- Support for subcommands and mutual exclusion groups.
- Validation hooks for parsed values.

# Typical workflow
1. Define a command struct with `@CMD_MAIN`.
2. Parse CLI arguments via `MyCommand(args)` or `parse_cli(MyCommand, args)`.
3. Catch `ArgHelpRequested` and `ArgParseError` at application entrypoint.

# Exceptions
- `ArgHelpRequested`: raised when help output is requested.
- `ArgParseError`: raised on invalid or inconsistent user input.
"""
module RunicCLI

using TextWrap
using Base: @kwdef

export ArgParseError, ArgHelpRequested, ArgHelpTemplate, ArgDef, SubcommandDef, CliDef
export ArgKind, AK_FLAG, AK_COUNT, AK_OPTION, AK_OPTION_MULTI, AK_POS_REQUIRED, AK_POS_DEFAULT, AK_POS_OPTIONAL, AK_POS_REST
export HelpStyle, HELP_PLAIN, HELP_COLORED, HelpTheme, HelpFormatOptions, build_help_template

export @CMD_MAIN, @CMD_SUB
export @CMD_USAGE, @CMD_DESC, @CMD_EPILOG
export @ARG_REQ, @ARG_DEF, @ARG_OPT, @ARG_FLAG, @ARG_COUNT, @ARG_MULTI
export @POS_REQ, @POS_DEF, @POS_OPT, @POS_REST
export @ARG_TEST, @ARG_STREAM
export @GROUP_EXCL, @ALLOW_EXTRA

export parse_cli, run_cli, render_help, default_help_template, colored_help_template

include("types.jl")
include("errors.jl")
include("parser_utils.jl")
include("help.jl")
include("ast_utils.jl")

include("macros/common.jl")
include("macros/compiler.jl")
include("macros/generators.jl")
include("macros/subcommands.jl") 
include("macros/placeholders.jl")
include("macros/entry.jl")

end # module