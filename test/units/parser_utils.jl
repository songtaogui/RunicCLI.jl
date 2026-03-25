using Test
using RunicCLI
using RunicCLIRuntime

@testset "parser utilities" begin
    @testset "split multiflag and arguments" begin
        @test RunicCLIRuntime._split_multiflag("-abc") == ["-a", "-b", "-c"]
        @test_throws RunicCLIRuntime.ArgParseError RunicCLIRuntime._split_multiflag("-a1")

        v = RunicCLIRuntime._split_arguments(["-abc", "--name=tom", "file"])
        @test v == ["-a", "-b", "-c", "--name", "tom", "file"]

        v2 = RunicCLIRuntime._split_arguments(["--", "-abc", "--x=1"])
        @test v2 == ["--", "-abc", "--x=1"]

        @test_throws RunicCLIRuntime.ArgParseError RunicCLIRuntime._split_arguments(["-ab=1"])
    end

    @testset "help flag detection before --" begin
        @test RunicCLIRuntime._has_help_flag_before_dd(["--help"]) == true
        @test RunicCLIRuntime._has_help_flag_before_dd(["-h"]) == true
        @test RunicCLIRuntime._has_help_flag_before_dd(["--", "--help"]) == false
        @test RunicCLIRuntime._has_help_flag_before_dd(["run", "--help"]) == true
    end

    @testset "value parsing primitives" begin
        @test RunicCLIRuntime._parse_value(Int, "42", "n") == 42
        @test RunicCLIRuntime._parse_value(Float64, "1.5", "x") == 1.5
        @test RunicCLIRuntime._parse_value(Bool, "yes", "b") == true
        @test RunicCLIRuntime._parse_value(Bool, "off", "b") == false
        @test_throws RunicCLIRuntime.ArgParseError RunicCLIRuntime._parse_value(Bool, "maybe", "b")
    end

    @testset "subcommand location logic" begin
        sub_names = ["run", "echo"]
        needv = Set(["-p", "--port"])
        nov = Set(["-v", "--verbose"])

        @test RunicCLIRuntime._locate_subcommand(["run"], sub_names, needv, nov) == ("run", 1)
        @test RunicCLIRuntime._locate_subcommand(["-v", "run"], sub_names, needv, nov) == ("run", 2)
        @test RunicCLIRuntime._locate_subcommand(["--port", "8080", "run"], sub_names, needv, nov) == ("run", 3)
        @test RunicCLIRuntime._locate_subcommand(["--", "run"], sub_names, needv, nov) == (nothing, 0)
        @test RunicCLIRuntime._locate_subcommand(["--unknown", "run"], sub_names, needv, nov) == (nothing, 0)
    end
end
