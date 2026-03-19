using Test
using RunicCLI

@CMD_MAIN BasicCmdForTest begin
    @CMD_USAGE "basic [OPTIONS] SRC [DST]"
    @CMD_DESC "Basic command description."
    @CMD_EPILOG "Basic command epilog."

    @ARG_REQ Int port "-p" "--port" help="Port number"
    @ARG_DEF String "localhost" host "-H" "--host" help="Host name"
    @ARG_OPT Float64 ratio "-r" "--ratio" help="Ratio value"
    @ARG_FLAG verbose "-v" "--verbose" help="Verbose switch"
    @ARG_COUNT quiet "-q" help="Quiet level"
    @ARG_MULTI Int nums "-n" "--num" help="Multiple integers"

    @POS_REQ String src help="Source path"
    @POS_DEF String "out.txt" dst help="Destination path"
    @POS_OPT Int retry help="Retry count"
    @POS_REST String rest help="Remaining args"

    @ARG_TEST port x->x>0 "port must be > 0"
    @ARG_STREAM nums x->x>0 "all nums must be > 0"

    @GROUP_EXCL verbose quiet
end

@testset "main parser basic behavior" begin
    @testset "success case" begin
        argv = ["--port", "8080", "--host", "example.com", "--ratio", "0.25",
                "-n", "1", "-n", "2", "input.txt", "output.txt", "3", "a", "b"]
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

    @testset "group exclusive conflict" begin
        @test_throws RunicCLI.ArgParseError parse_cli(BasicCmdForTest, ["-p", "1", "-v", "-q", "src"])
    end

    @testset "validators" begin
        @test_throws RunicCLI.ArgParseError parse_cli(BasicCmdForTest, ["-p", "0", "src"])
        @test_throws RunicCLI.ArgParseError parse_cli(BasicCmdForTest, ["-p", "1", "-n", "-1", "src"])
    end

    @testset "required and duplicate option failures" begin
        @test_throws RunicCLI.ArgParseError parse_cli(BasicCmdForTest, ["src"])
        @test_throws RunicCLI.ArgParseError parse_cli(BasicCmdForTest, ["-p", "1", "-p", "2", "src"])
    end

    @testset "negative positional via -- passthrough" begin
        obj = parse_cli(BasicCmdForTest, ["-p", "9", "--", "-1"])
        @test obj.src == "-1"
    end

    @testset "help request" begin
        try
            parse_cli(BasicCmdForTest, ["--help"])
            @test false
        catch e
            @test e isa RunicCLI.ArgHelpRequested
            @test occursin("Usage:", e.message)
            @test occursin("Option Arguments:", e.message)
            @test occursin("Positional Arguments:", e.message)
        end
    end
end
