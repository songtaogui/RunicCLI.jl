using Test
using Oracli
using OracliRuntime

@testset "parser utilities" begin
    @testset "split multiflag and arguments" begin
        @test OracliRuntime.split_multiflag("-abc") == ["-a", "-b", "-c"]
        @test_throws OracliRuntime.ArgParseError OracliRuntime.split_multiflag("-a1")

        v = OracliRuntime.split_arguments(["-abc", "--name=tom", "file"])
        @test v == ["-a", "-b", "-c", "--name", "tom", "file"]

        v2 = OracliRuntime.split_arguments(["--", "-abc", "--x=1"])
        @test v2 == ["--", "-abc", "--x=1"]

        @test_throws OracliRuntime.ArgParseError OracliRuntime.split_arguments(["-ab=1"])
    end

    @testset "help flag detection before --" begin
        @test OracliRuntime.has_help_flag_before_dd(["--help"]) == true
        @test OracliRuntime.has_help_flag_before_dd(["-h"]) == true
        @test OracliRuntime.has_help_flag_before_dd(["--", "--help"]) == false
        @test OracliRuntime.has_help_flag_before_dd(["run", "--help"]) == true
    end

    @testset "value parsing primitives" begin
        @test OracliRuntime.parse_value(Int, "42", "n") == 42
        @test OracliRuntime.parse_value(Float64, "1.5", "x") == 1.5
        @test OracliRuntime.parse_value(Bool, "yes", "b") == true
        @test OracliRuntime.parse_value(Bool, "off", "b") == false
        @test_throws OracliRuntime.ArgParseError OracliRuntime.parse_value(Bool, "maybe", "b")
    end

    @testset "subcommand location logic" begin
        sub_names = ["run", "echo"]
        needv = Set(["-p", "--port"])
        nov = Set(["-v", "--verbose"])

        @test OracliRuntime.locate_subcommand(["run"], sub_names, needv, nov) == ("run", 1)
        @test OracliRuntime.locate_subcommand(["-v", "run"], sub_names, needv, nov) == ("run", 2)
        @test OracliRuntime.locate_subcommand(["--port", "8080", "run"], sub_names, needv, nov) == ("run", 3)
        @test OracliRuntime.locate_subcommand(["--", "run"], sub_names, needv, nov) == (nothing, 0)
        @test OracliRuntime.locate_subcommand(["--unknown", "run"], sub_names, needv, nov) == (nothing, 0)
    end
end
