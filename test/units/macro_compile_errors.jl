using Test
using RunicCLI

@testset "macro compile-time validation" begin
    @testset "placeholder macros must fail outside CMD_MAIN/CMD_SUB" begin
        @test_throws ArgumentError macroexpand(@__MODULE__, :(@ARG_FLAG verbose "-v" "--verbose"))
        @test_throws ArgumentError macroexpand(@__MODULE__, :(@POS_REQ String src))
        @test_throws ArgumentError macroexpand(@__MODULE__, :(@CMD_DESC "desc"))
    end

    @testset "CMD_MAIN shape and non-macro nodes" begin
        ex1 = quote
            @CMD_MAIN Bad1 begin
                x = 1
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex1)

        ex2 = :(@CMD_MAIN "BadType" begin end)
        @test_throws ArgumentError macroexpand(@__MODULE__, ex2)
    end

    @testset "duplicate names and flags" begin
        ex_dup_arg = quote
            @CMD_MAIN BadDupArg begin
                @ARG_FLAG verbose "-v"
                @ARG_COUNT verbose "-q"
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_dup_arg)

        ex_dup_flag = quote
            @CMD_MAIN BadDupFlag begin
                @ARG_FLAG a "-v"
                @ARG_FLAG b "-v"
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_dup_flag)
    end

    @testset "group exclusivity declaration checks" begin
        ex_unknown = quote
            @CMD_MAIN BadGroupUnknown begin
                @ARG_FLAG a "-a"
                @GROUP_EXCL a b
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_unknown)

        ex_pos_not_allowed = quote
            @CMD_MAIN BadGroupPos begin
                @POS_REQ String x
                @ARG_FLAG y "-y"
                @GROUP_EXCL x y
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_pos_not_allowed)
    end

    @testset "POS_REST must be last" begin
        ex_rest_last = quote
            @CMD_MAIN BadPosRest begin
                @POS_REST String rest
                @POS_REQ String x
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_rest_last)
    end

    @testset "help keyword validation" begin
        ex_bad_kw = quote
            @CMD_MAIN BadHelpKw begin
                @ARG_FLAG a "-a" foo="bar"
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_bad_kw)

        ex_dup_help = quote
            @CMD_MAIN BadDupHelp begin
                @ARG_FLAG a "-a" help="x" help="y"
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_dup_help)
    end
end
