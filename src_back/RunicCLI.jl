module RunicCLI

using TextWrap
using Base: @kwdef

export ArgParseError, ArgHelpRequested, ArgHelpTemplate
export ArgDef, SubcommandDef, CliDef
export ArgRequiresDef, ArgConflictsDef
export ArgKind, AK_FLAG, AK_COUNT, AK_OPTION, AK_OPTION_MULTI, AK_POS_REQUIRED, AK_POS_DEFAULT, AK_POS_OPTIONAL, AK_POS_REST

export HelpStyle, HELP_PLAIN, HELP_COLORED
export HelpLabelStyle, HLS_HIDDEN, HLS_PLAIN, HLS_BOLD, HLS_COLORED
export HelpTheme, HelpFormatOptions, HelpTemplateOptions, build_help_template

export @CMD_MAIN, @CMD_SUB
export @CMD_USAGE, @CMD_DESC, @CMD_EPILOG
export @ARG_REQ, @ARG_DEF, @ARG_OPT, @ARG_FLAG, @ARG_COUNT, @ARG_MULTI
export @POS_REQ, @POS_DEF, @POS_OPT, @POS_REST
export @ARG_TEST, @ARG_STREAM
export @GROUP_EXCL, @GROUP_INCL, @ARG_REQUIRES, @ARG_CONFLICTS, @ALLOW_EXTRA

export parse_cli, run_cli, render_help, default_help_template, colored_help_template


include("core/types.jl")
include("core/errors.jl")
include("core/parser_utils.jl")
include("core/ast_utils.jl")

include("help/config.jl")
include("help/utils.jl")
include("help/layout.jl")
include("help/template.jl")
include("help/render.jl")

include("runtime/api.jl")
include("runtime/execution.jl")

include("macros/common.jl")
include("macros/compiler.jl")
include("macros/generators.jl")
include("macros/subcommands.jl") 
include("macros/placeholders.jl")
include("macros/cmd_main.jl")

end