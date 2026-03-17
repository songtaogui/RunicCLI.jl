using Test
using RunicCLI

include("test_macro_compile_errors.jl")
include("test_parser_utils.jl")
include("test_main_parse_basic.jl")
include("test_subcommands.jl")
include("test_help_render.jl")
include("test_run_cli_and_errors.jl")
include("test_edge_coverage.jl")