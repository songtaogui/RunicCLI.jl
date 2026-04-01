
@testset "fallback on optional option arguments" begin
    @CMD_MAIN FallbackOptCli begin
        @ARG_OPT String b "--b"
        @ARG_OPT String a "--a" fallback=b
    end

    @test parse_cli(FallbackOptCli, ["--a", "x"]).a == "x"
    @test parse_cli(FallbackOptCli, ["--a", "x"]).b === nothing

    r = parse_cli(FallbackOptCli, ["--b", "y"])
    @test r.b == "y"
    @test r.a == "y"

    r2 = parse_cli(FallbackOptCli, ["--a", "x", "--b", "y"])
    @test r2.a == "x"
    @test r2.b == "y"

    r3 = parse_cli(FallbackOptCli, String[])
    @test r3.a === nothing
    @test r3.b === nothing
end

@testset "fallback on optional positional arguments" begin
    @CMD_MAIN FallbackPosCli begin
        @POS_OPT String b
        @POS_OPT String a fallback=b
    end

    r1 = parse_cli(FallbackPosCli, ["bbb"])
    @test r1.b == "bbb"
    @test r1.a == "bbb"

    r2 = parse_cli(FallbackPosCli, ["bbb", "aaa"])
    @test r2.b == "bbb"
    @test r2.a == "aaa"

    r3 = parse_cli(FallbackPosCli, String[])
    @test r3.a === nothing
    @test r3.b === nothing
end

@testset "fallback uses final value of target" begin
    @CMD_MAIN FallbackChainCli begin
        @ARG_OPT String c "--c" default="c_value"
        @ARG_OPT String b "--b" fallback=c
        @ARG_OPT String a "--a" fallback=b
    end

    r = parse_cli(FallbackChainCli, String[])
    @test r.c == "c_value"
    @test r.b == "c_value"
    @test r.a == "c_value"
end


@testset "fallback prefers CLI/env/default before fallback" begin
    @CMD_MAIN FallbackPriorityCli begin
        @ARG_OPT String b "--b" default="BDEF"
        @ARG_OPT String a "--a" default="ADEF" fallback=b
    end

    r1 = parse_cli(FallbackPriorityCli, String[])
    @test r1.b == "BDEF"
    @test r1.a == "ADEF"

    r2 = parse_cli(FallbackPriorityCli, ["--b", "BCLI"])
    @test r2.b == "BCLI"
    @test r2.a == "ADEF"

    r3 = parse_cli(FallbackPriorityCli, ["--a", "ACLI", "--b", "BCLI"])
    @test r3.a == "ACLI"
    @test r3.b == "BCLI"
end

@testset "fallback semantic validation" begin
    err1 = try
        @eval begin
            @CMD_MAIN FallbackUnknownCli begin
                @ARG_OPT String a "--a" fallback=b
            end
        end
        nothing
    catch e
        e
    end

    @test err1.error isa ArgumentError
    @test occursin("fallback", sprint(showerror, err1))
    @test occursin("unknown argument", sprint(showerror, err1))

    err2 = try
        @eval begin
            @CMD_MAIN FallbackBadSourceCli begin
                @ARG_FLAG a "--a"
                @ARG_OPT String b "--b"
            end
        end
        nothing
    catch e
        e
    end

    err3 = try
        @eval begin
            @CMD_MAIN FallbackBadTargetCli begin
                @ARG_OPT String a "--a" fallback=r
                @POS_REST String r
            end
        end
        nothing
    catch e
        e
    end

    @test err3.error isa ArgumentError
    @test occursin("fallback target must be a value-bearing non-rest argument", sprint(showerror, err3))

    err4 = try
        @eval begin
            @CMD_MAIN FallbackCycleCli begin
                @ARG_OPT String a "--a" fallback=b
                @ARG_OPT String b "--b" fallback=a
            end
        end
        nothing
    catch e
        e
    end

    @test err4.error isa ArgumentError
    @test occursin("fallback cycle detected", sprint(showerror, err4))
end
