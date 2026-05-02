using Test
using Oracli
using Dates

include("units/macro_compile_errors.jl")
include("units/parser_utils.jl")
include("units/main_parse_basic.jl")
include("units/subcommands.jl")

include("units/help_rendering.jl")
include("units/help_parse_integration.jl")
include("units/help_grouping.jl")

include("units/run_cli_and_errors.jl")
include("units/edge_coverage.jl")
include("units/constraint_macros.jl")

include("units/arg_sources.jl")
include("units/arg_fallback.jl")
include("units/gen_completion.jl")
include("units/version.jl")

include("units/arg_validator_num_any.jl")
include("units/arg_validator_str.jl")
include("units/arg_validator_path_file_dir.jl")
include("units/arg_validator_cmd.jl")
include("units/arg_validator_file_index.jl")
include("units/arg_validator_bio_index.jl")
include("units/arg_validator_cli_integration.jl")
