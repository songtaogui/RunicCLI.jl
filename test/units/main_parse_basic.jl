using Test
using RunicCLI

@CMD_MAIN BasicCmdForTest begin
    @CMD_USAGE "basic [OPTIONS] SRC [DST]"
    @CMD_DESC "Basic command description."
    @CMD_EPILOG "Basic command epilog."

    @ARG_REQ Int port "-p" "--port" help="Port number"
    @ARG_OPT String host "-H" "--host" help="Host name" default="localhost"
    @ARG_OPT Float64 ratio "-r" "--ratio" help="Ratio value"
    @ARG_FLAG verbose "-v" "--verbose" help="Verbose switch"
    @ARG_COUNT quiet "-q" help="Quiet level"
    @ARG_MULTI Int nums "-n" "--num" help="Multiple integers"

    @POS_REQ String src help="Source path"
    @POS_OPT String dst help="Destination path" default="out.txt"
    @POS_OPT Int retry help="Retry count"
    @POS_REST String rest help="Remaining args"

    @ARG_TEST port x -> x > 0 "port must be > 0"
    @ARG_STREAM nums x -> x > 0 "all nums must be > 0"

    @ARGREL_ATMOSTONE verbose quiet help="verbose and quiet cannot be used together"
end

@CMD_MAIN AutoHelpMainCmdForTest begin
    @CMD_USAGE "automain [OPTIONS] SRC"
    @CMD_DESC "Main command with auto help."
    @CMD_AUTOHELP

    @ARG_REQ Int port "-p" "--port" help="Port number"
    @POS_REQ String src help="Source path"
end

@CMD_MAIN AutoHelpSubCmdForTest begin
    @CMD_USAGE "autosub [OPTIONS] <SUBCOMMAND>"
    @CMD_DESC "Command with subcommand auto help."

    @ARG_FLAG verbose "-v" "--verbose" help="Verbose switch"

    @CMD_SUB "run" begin
        @CMD_DESC "Run subcommand."
        @CMD_AUTOHELP

        @ARG_REQ Int count "-n" "--count" help="Count value"
    end
end

@testset "main parser basic behavior" begin
    @testset "success case" begin
        argv = [
            "--port", "8080",
            "--host", "example.com",
            "--ratio", "0.25",
            "-n", "1",
            "-n", "2",
            "input.txt", "output.txt", "3", "a", "b"
        ]
        obj = parse_cli(BasicCmdForTest, argv)

        @test obj.port == 8080
        @test obj.host == "example.com"
        @test obj.ratio == 0.25
        @test obj.verbose == false
        @test obj.quiet == 0
        @test obj.nums == [1, 2]
        @test obj.src == "input.txt"
        @test obj.dst == "output.txt"
        @test obj.retry == 3
        @test obj.rest == ["a", "b"]
        @test isnothing(obj.subcommand)
        @test isnothing(obj.subcommand_args)
    end

    @testset "defaults and optionals" begin
        obj = parse_cli(BasicCmdForTest, ["-p", "1", "src-only"])
        @test obj.host == "localhost"
        @test isnothing(obj.ratio)
        @test obj.dst == "out.txt"
        @test isnothing(obj.retry)
        @test isempty(obj.rest)
    end

    @testset "at most one conflict" begin
        err = try
            parse_cli(BasicCmdForTest, ["-p", "1", "-v", "-q", "src"])
            nothing
        catch e
            e
        end

        @test err isa RunicCLI.ArgParseError
        @test occursin("verbose and quiet cannot be used together", err.message)
    end

    @testset "validators" begin
        err1 = try
            parse_cli(BasicCmdForTest, ["-p", "0", "src"])
            nothing
        catch e
            e
        end
        @test err1 isa RunicCLI.ArgParseError
        @test occursin("port must be > 0", err1.message)

        err2 = try
            parse_cli(BasicCmdForTest, ["-p", "1", "-n", "-1", "src"])
            nothing
        catch e
            e
        end
        @test err2 isa RunicCLI.ArgParseError
        @test occursin("all nums must be > 0", err2.message)
    end

    @testset "required and duplicate option failures" begin
        @test_throws RunicCLI.ArgParseError parse_cli(BasicCmdForTest, ["src"])
        @test_throws RunicCLI.ArgParseError parse_cli(BasicCmdForTest, ["-p", "1", "-p", "2", "src"])
    end

    @testset "negative positional via double dash passthrough" begin
        obj = parse_cli(BasicCmdForTest, ["-p", "9", "--", "-1"])
        @test obj.src == "-1"
    end

    @testset "help request" begin
        try
            parse_cli(BasicCmdForTest, ["--help"])
            @test false
        catch e
            @test e isa RunicCLI.ArgHelpRequested
            @test occursin("Options:", e.message)
            @test occursin("Positional Arguments:", e.message)
        end
    end

    @testset "main auto help" begin
        try
            parse_cli(AutoHelpMainCmdForTest, String[])
            @test false
        catch e
            @test e isa RunicCLI.ArgHelpRequested
            @test occursin("Options:", e.message)
        end
    end

    @testset "subcommand auto help" begin
        try
            parse_cli(AutoHelpSubCmdForTest, ["run"])
            @test false
        catch e
            @test e isa RunicCLI.ArgHelpRequested
            @test occursin("Run subcommand.", e.message)
        end
    end
end
