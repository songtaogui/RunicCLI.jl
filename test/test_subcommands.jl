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
end
