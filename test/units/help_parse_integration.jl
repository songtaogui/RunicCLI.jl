using Test
using RunicCLI

@testset "parse_cli and run_cli help integration" begin
    @CMD_MAIN HelpDemo begin
        @CMD_DESC "Demo command."
        @ARG_REQ Int port "-p" "--port" help="Port value"
        @ARG_FLAG verbose "-v" "--verbose" help="Verbose mode"
        @POS_REQ String src help="Source file"

        @CMD_SUB "run" "Run job" begin
            @ARG_FLAG dryrun "--dry-run" help="Dry run"
        end
    end

    @testset "parse_cli root help uses resolved template" begin
        err = try
            parse_cli(
                HelpDemo,
                ["--help"];
                help=HelpTemplateOptions(
                    style = HELP_PLAIN,
                    title_usage = "USAGE:"
                ),
            )
            nothing
        catch e
            e
        end

        @test err isa ArgHelpRequested
        @test occursin("USAGE:", err.message)
        @test occursin("<port>::Int", err.message)
        @test occursin("Source file", err.message)
        @test occursin("Run job", err.message)
    end

    @testset "parse_cli subcommand help uses resolved template" begin
        err = try
            parse_cli(
                HelpDemo,
                ["run", "--help"];
                help=HelpTemplateOptions(
                    style = HELP_PLAIN,
                    title_usage = "USAGE:",
                )
            )
            nothing
        catch e
            e
        end

        @test err isa ArgHelpRequested
        @test occursin("USAGE:", err.message)
        @test occursin("Run job", err.message)
        @test occursin("--dry-run", err.message)
    end

    @testset "run_cli prints help to io and returns 0" begin
        out = IOBuffer()
        errio = IOBuffer()

        code = run_cli(
            () -> parse_cli(
                HelpDemo,
                ["--help"];
                help=HelpTemplateOptions(title_usage = "USAGE:")
            );
            io = out,
            err_io = errio
        )

        txt = String(take!(out))
        errtxt = String(take!(errio))

        @test code == 0
        @test occursin("USAGE:", txt)
        @test isempty(errtxt)
    end

    @testset "subcommand help bypasses main required args" begin
        err = try
            parse_cli(HelpDemo, ["run", "--help"])
            nothing
        catch e
            e
        end

        @test err isa ArgHelpRequested
        @test !occursin("Missing required option --port", err.message)
    end

    @testset "subcommand execution still requires main required args" begin
        err = try
            parse_cli(HelpDemo, ["run"])
            nothing
        catch e
            e
        end

        @test err isa ArgParseError
        @test occursin("Missing required option --port", err.message)
    end

end
