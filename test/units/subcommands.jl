using Test
using RunicCLI

@CMD_MAIN AppCmdForTest begin
    @CMD_DESC "Main app command"
    @ARG_FLAG global "-g" "--global" help="Global switch"

    @CMD_SUB "run" "Run subcommand" begin
        @ARG_REQ Int id "-i" "--id" help="Task id"
        @ARG_FLAG dry "--dry" help="Dry run"
    end

    @CMD_SUB "echo" begin
        @CMD_DESC "Echo subcommand"
        @POS_REQ String text help="Text"
        @ALLOW_EXTRA
    end
end

@CMD_MAIN OnlySubcommandsForTest begin
    @CMD_SUB "run" "Run subcommand" begin
        @ARG_REQ Int id "-i" "--id" help="Task id"
    end
end

@CMD_MAIN GlobalAfterSubcommandForTest begin
    @ARG_OPT Float64 ratio "-r" "--ratio" help="Global ratio" default=1.0
    @ARG_FLAG verbose "-v" "--verbose" help="Verbose"

    @CMD_SUB "run" "Run subcommand" begin
        @ARG_REQ String format "-f" "--format" help="Format"
        @POS_OPT String output help="Output"
    end
end

@testset "subcommand behavior" begin
    @testset "dispatch run" begin
        obj = parse_cli(AppCmdForTest, ["-g", "run", "--id", "7", "--dry"])
        @test obj.global == true
        @test obj.subcommand == "run"
        @test obj.subcommand_args.id == 7
        @test obj.subcommand_args.dry == true
    end

    @testset "dispatch echo" begin
        obj = parse_cli(AppCmdForTest, ["echo", "hello", "extra", "tokens"])
        @test obj.subcommand == "echo"
        @test obj.subcommand_args.text == "hello"
    end

    @testset "subcommand help" begin
        try
            parse_cli(AppCmdForTest, ["run", "--help"])
            @test false
        catch e
            @test e isa RunicCLI.ArgHelpRequested
            @test occursin("run", e.message)
            @test occursin("Task id", e.message)
        end
    end

    @testset "main help includes subcommands" begin
        try
            parse_cli(AppCmdForTest, ["--help"])
            @test false
        catch e
            @test e isa RunicCLI.ArgHelpRequested
            @test occursin("Subcommands:", e.message)
            @test occursin("run", e.message)
            @test occursin("echo", e.message)
        end
    end

    @testset "main with only subcommands does not crash" begin
        obj = parse_cli(OnlySubcommandsForTest, ["run", "--id", "12"])
        @test obj.subcommand == "run"
        @test obj.subcommand_args.id == 12
    end

    @testset "global options can appear before subcommand" begin
        obj = parse_cli(GlobalAfterSubcommandForTest, ["-r", "0.2", "run", "-f", "ABC"])
        @test obj.ratio == 0.2
        @test obj.verbose == false
        @test obj.subcommand == "run"
        @test obj.subcommand_args.format == "ABC"
        @test obj.subcommand_args.output === nothing
    end

    @testset "global options can appear after subcommand" begin
        obj = parse_cli(GlobalAfterSubcommandForTest, ["run", "-r", "0.2", "-f", "ABC"])
        @test obj.ratio == 0.2
        @test obj.verbose == false
        @test obj.subcommand == "run"
        @test obj.subcommand_args.format == "ABC"
        @test obj.subcommand_args.output === nothing
    end

    @testset "global options can appear after subcommand options" begin
        obj = parse_cli(GlobalAfterSubcommandForTest, ["run", "-f", "ABC", "-r", "0.2"])
        @test obj.ratio == 0.2
        @test obj.verbose == false
        @test obj.subcommand == "run"
        @test obj.subcommand_args.format == "ABC"
        @test obj.subcommand_args.output === nothing
    end

    @testset "global flag can appear after subcommand" begin
        obj = parse_cli(GlobalAfterSubcommandForTest, ["run", "-f", "ABC", "-v"])
        @test obj.ratio == 1.0
        @test obj.verbose == true
        @test obj.subcommand == "run"
        @test obj.subcommand_args.format == "ABC"
    end

    @testset "unknown option is not consumed as positional" begin
        @test_throws RunicCLI.ArgParseError parse_cli(GlobalAfterSubcommandForTest, ["run", "-f", "ABC", "--unknown"])
    end

    @testset "subcommand unknown option is not consumed as positional" begin
        @test_throws RunicCLI.ArgParseError parse_cli(GlobalAfterSubcommandForTest, ["run", "-f", "ABC", "-x", "out.txt"])
    end

    @testset "dash-like positional still requires explicit separator" begin
        obj = parse_cli(GlobalAfterSubcommandForTest, ["run", "-f", "ABC", "--", "-x"])
        @test obj.subcommand == "run"
        @test obj.subcommand_args.format == "ABC"
        @test obj.subcommand_args.output == "-x"
    end
end
