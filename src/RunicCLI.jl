module RunicCLI

using Reexport
import RunicCLIRuntime
@reexport using RunicCLIRuntime
using Base: @kwdef

const _RT = RunicCLIRuntime

"""Create a `GlobalRef` pointing to a symbol in `RunicCLIRuntime`."""
_gr(s::Symbol) = GlobalRef(_RT, s)

export @CMD_MAIN, @CMD_SUB
export @CMD_USAGE, @CMD_DESC, @CMD_EPILOG, @CMD_VERSION, @CMD_AUTOHELP
export @ARG_REQ, @ARG_OPT, @ARG_FLAG, @ARG_COUNT, @ARG_MULTI
export @POS_REQ, @POS_OPT, @POS_REST
export @ARG_TEST, @ARG_STREAM
export @ARGREL_DEPENDS, @ARGREL_CONFLICTS, @ARGREL_ATMOSTONE, @ARGREL_ATLEASTONE, @ARGREL_ONLYONE, @ARGREL_ALLORNONE
export @ALLOW_EXTRA, @ARG_GROUP

include("core/symbols.jl")
include("core/ast_utils.jl")

include("engine/ir_types.jl")
include("engine/semantic_checks.jl")
include("engine/dsl_parser.jl")
include("engine/parser_codegen.jl")
include("engine/build_cmd_main_expr.jl")

include("macros/placeholders.jl")
include("macros/entrypoints.jl")

end
