module RunicCLI

import RunicCLIRuntime
using RunicCLIRuntime
using Base: @kwdef

const _RT = RunicCLIRuntime
_gr(s::Symbol) = GlobalRef(_RT, s)

# Re-export runtime public API for backward compatibility
export ArgParseError, ArgHelpRequested, ArgHelpTemplate
export ArgDef, SubcommandDef, CliDef
export ArgRequiresDef, ArgConflictsDef
export ArgKind, AK_FLAG, AK_COUNT, AK_OPTION, AK_OPTION_MULTI, AK_POS_REQUIRED, AK_POS_OPTIONAL, AK_POS_REST

export HelpStyle, HELP_PLAIN, HELP_COLORED
export HelpLabelStyle, HLS_HIDDEN, HLS_PLAIN, HLS_BOLD, HLS_COLORED
export HelpTheme, HelpFormatOptions, HelpTemplateOptions, build_help_template

export parse_cli, run_cli, render_help, default_help_template, colored_help_template
export load_config_file, merge_cli_sources, generate_completion
export generate_default_config, save_default_config

export v_min, v_max, v_range, v_oneof, v_include, v_exclude
export v_length, v_prefix, v_suffix, v_regex
export v_exists, v_isfile, v_isdir, v_readable, v_writable
export v_and, v_or

# Compiler-side exports
export @CMD_MAIN, @CMD_SUB
export @CMD_USAGE, @CMD_DESC, @CMD_EPILOG, @CMD_VERSION
export @ARG_REQ, @ARG_OPT, @ARG_FLAG, @ARG_COUNT, @ARG_MULTI
export @POS_REQ, @POS_OPT, @POS_REST
export @ARG_TEST, @ARG_STREAM
export @GROUP_EXCL, @GROUP_INCL, @ARG_REQUIRES, @ARG_CONFLICTS, @ALLOW_EXTRA

include("core/symbols.jl")
include("core/ast_utils.jl")

include("spec/dsl_contract.jl")
include("spec/parse_pipeline.jl")
include("spec/error_contract.jl")

include("engine/ir_types.jl")
include("engine/semantic_checks.jl")
include("engine/dsl_parser.jl")
include("engine/parser_codegen.jl")
include("engine/build_cmd_main_expr.jl")

include("macros/placeholders.jl")
include("macros/entrypoints.jl")

end
