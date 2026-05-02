using Test
using Oracli

@testset "run_cli and error surfaces" begin
    @testset "help exception path" begin
        out = IOBuffer()
        err = IOBuffer()

        code = run_cli(io=out, err_io=err) do
            throw(ArgHelpRequested("help text"))
        end

        @test code == 0
        @test String(take!(out)) == "help text\n"
        @test isempty(String(take!(err)))
    end

    @testset "parse error path with callback" begin
        out = IOBuffer()
        err = IOBuffer()
        seen = Ref(false)

        code = run_cli(io=out, err_io=err, on_error = e -> (seen[] = e isa ArgParseError)) do
            throw(ArgParseError("bad input"))
        end

        @test code == 2
        @test seen[] == true
        msg = String(take!(err))
        @test occursin("Argument parsing error: bad input", msg)
    end

    @testset "normal success path" begin
        out = IOBuffer()
        err = IOBuffer()

        code = run_cli(io=out, err_io=err) do
            nothing
        end

        @test code == 0
        @test isempty(String(take!(out)))
        @test isempty(String(take!(err)))
    end

    @testset "unexpected exception rethrow" begin
        @test_throws ErrorException run_cli() do
            error("unexpected")
        end
    end
end
