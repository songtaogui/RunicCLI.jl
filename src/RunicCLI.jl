module RunicCLI

using TextWrap
using Base: @kwdef
using TOML

export ArgParseError, ArgHelpRequested, ArgHelpTemplate
export ArgDef, SubcommandDef, CliDef
export ArgRequiresDef, ArgConflictsDef
export ArgKind, AK_FLAG, AK_COUNT, AK_OPTION, AK_OPTION_MULTI, AK_POS_REQUIRED, AK_POS_DEFAULT, AK_POS_OPTIONAL, AK_POS_REST

export HelpStyle, HELP_PLAIN, HELP_COLORED
export HelpLabelStyle, HLS_HIDDEN, HLS_PLAIN, HLS_BOLD, HLS_COLORED
export HelpTheme, HelpFormatOptions, HelpTemplateOptions, build_help_template

export @CMD_MAIN, @CMD_SUB
export @CMD_USAGE, @CMD_DESC, @CMD_EPILOG, @CMD_VERSION
export @ARG_REQ, @ARG_DEF, @ARG_OPT, @ARG_FLAG, @ARG_COUNT, @ARG_MULTI
export @POS_REQ, @POS_DEF, @POS_OPT, @POS_REST
export @ARG_TEST, @ARG_STREAM
export @GROUP_EXCL, @GROUP_INCL, @ARG_REQUIRES, @ARG_CONFLICTS, @ALLOW_EXTRA

export parse_cli, run_cli, render_help, default_help_template, colored_help_template
export load_config_file, merge_cli_sources, generate_completion
export v_min, v_max, v_range, v_oneof, v_include, v_exclude
export v_length, v_prefix, v_suffix, v_regex
export v_exists, v_isfile, v_isdir, v_readable, v_writable
export v_and, v_or

include("core/types.jl")
include("core/errors.jl")
include("core/parser_utils.jl")
include("core/ast_utils.jl")

include("help/config.jl")
include("help/utils.jl")
include("help/layout.jl")
include("help/template.jl")
include("help/render.jl")

include("runtime/execution.jl")
include("runtime/validators.jl")
include("runtime/sources.jl")
include("runtime/completion.jl") 
include("runtime/api.jl")

include("macros/common.jl")
include("macros/compiler.jl")
include("macros/generators.jl")
include("macros/subcommands.jl")
include("macros/placeholders.jl")
include("macros/cmd_main.jl")

end
