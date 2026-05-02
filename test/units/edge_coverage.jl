# FILEPATH: test/test_edge_coverage.jl
using Test
using Oracli

@testset "edge coverage: macro entry validation" begin
    @testset "CMD_MAIN argument shape checks" begin
        ex_no_block = :(@CMD_MAIN NoBlock "not block")
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_no_block)

        ex_bad_name = :(@CMD_MAIN A.B begin end)
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_bad_name)
    end

    @testset "duplicate command metadata in main" begin
        ex_dup_usage = quote
            @CMD_MAIN DupUsageMain begin
                @CMD_USAGE "u1"
                @CMD_USAGE "u2"
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_dup_usage)

        ex_dup_desc = quote
            @CMD_MAIN DupDescMain begin
                @CMD_DESC "d1"
                @CMD_DESC "d2"
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_dup_desc)

        ex_dup_epilog = quote
            @CMD_MAIN DupEpiMain begin
                @CMD_EPILOG "e1"
                @CMD_EPILOG "e2"
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_dup_epilog)

        ex_dup_allow = quote
            @CMD_MAIN DupAllowMain begin
                @ALLOW_EXTRA
                @ALLOW_EXTRA
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_dup_allow)
    end

    @testset "CMD_SUB shape and semantic checks" begin
        ex_sub_missing_block = quote
            @CMD_MAIN SubMissingBlock begin
                @CMD_SUB "run"
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_sub_missing_block)

        ex_sub_bad_name = quote
            @CMD_MAIN SubBadName begin
                @CMD_SUB :run begin end
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_sub_bad_name)

        ex_sub_name_starts_dash = quote
            @CMD_MAIN SubDashName begin
                @CMD_SUB "--run" begin end
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_sub_name_starts_dash)

        ex_sub_bad_5arg_shape = quote
            @CMD_MAIN SubBadFive begin
                @CMD_SUB "run" 123 begin end
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_sub_bad_5arg_shape)

        ex_sub_non_block = quote
            @CMD_MAIN SubNonBlock begin
                @CMD_SUB "run" "desc" "not block"
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_sub_non_block)

        ex_dup_sub_name = quote
            @CMD_MAIN DupSub begin
                @CMD_SUB "run" begin end
                @CMD_SUB "run" begin end
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_dup_sub_name)
    end

    @testset "subcommand metadata duplicates" begin
        ex_dup_sub_desc = quote
            @CMD_MAIN DupSubDesc begin
                @CMD_SUB "run" "d0" begin
                    @CMD_DESC "d1"
                end
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_dup_sub_desc)

        ex_dup_sub_usage = quote
            @CMD_MAIN DupSubUsage begin
                @CMD_SUB "run" begin
                    @CMD_USAGE "u1"
                    @CMD_USAGE "u2"
                end
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_dup_sub_usage)

        ex_dup_sub_epilog = quote
            @CMD_MAIN DupSubEpilog begin
                @CMD_SUB "run" begin
                    @CMD_EPILOG "e1"
                    @CMD_EPILOG "e2"
                end
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_dup_sub_epilog)

        ex_dup_sub_allow = quote
            @CMD_MAIN DupSubAllow begin
                @CMD_SUB "run" begin
                    @ALLOW_EXTRA
                    @ALLOW_EXTRA
                end
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_dup_sub_allow)
    end

    @testset "help_name and help keyword validation" begin
        ex_help_name_not_allowed = quote
            @CMD_MAIN BadHelpName1 begin
                @ARG_FLAG v "-v" help_name="VERB"
            end
        end
        # actually help_name is allowed for args; this should pass macroexpand
        @test macroexpand(@__MODULE__, ex_help_name_not_allowed) isa Expr

        ex_bad_help_name_type = quote
            @CMD_MAIN BadHelpName2 begin
                @ARG_REQ Int port "-p" help_name=123
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_bad_help_name_type)

        ex_bad_help_name_newline = quote
            @CMD_MAIN BadHelpName3 begin
                @ARG_REQ Int port "-p" help_name="X\nY"
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_bad_help_name_newline)

        ex_dup_help_name = quote
            @CMD_MAIN BadHelpName4 begin
                @ARG_REQ Int port "-p" help_name="A" help_name="B"
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_dup_help_name)

        ex_help_both_forms = quote
            @CMD_MAIN BadHelpBoth begin
                @POS_REQ String src help="x" "legacy"
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_help_both_forms)

        ex_unknown_kw = quote
            @CMD_MAIN BadUnknownKw begin
                @POS_REQ String src foo="bar"
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_unknown_kw)
    end

    @testset "validator declaration compile-time checks" begin
        ex_unknown_test = quote
            @CMD_MAIN UnknownTestRef begin
                @ARG_TEST port vfun=x->x>0
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_unknown_test)

        ex_unknown_stream = quote
            @CMD_MAIN UnknownStreamRef begin
                @ARG_STREAM nums x->x>0
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_unknown_stream)

        ex_bad_test_msg = quote
            @CMD_MAIN BadTestMsg begin
                @ARG_REQ Int port "-p"
                @ARG_TEST port vfun=x->x>0 vmsg=:bad
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_bad_test_msg)

        ex_bad_stream_msg = quote
            @CMD_MAIN BadStreamMsg begin
                @ARG_MULTI Int nums "-n"
                @ARG_STREAM nums x->x>0 :bad
            end
        end
        @test_throws ArgumentError macroexpand(@__MODULE__, ex_bad_stream_msg)
    end
end

@testset "edge coverage: parser utility branches" begin
    @testset "split multiflag rejects non ascii and invalid chars" begin
        @test_throws OracliRuntime.ArgParseError OracliRuntime.split_multiflag("-é")
        @test_throws OracliRuntime.ArgParseError OracliRuntime.split_multiflag("-a_")
    end

    @testset "split arguments with negative literal in short head" begin
        v = OracliRuntime.split_arguments(["-a1.5"])
        @test v == ["-a", "1.5"]
    end

    @testset "pop_value_last and pop_value behavior" begin
        args1 = ["--name", "a", "--name", "b", "tail"]
        v, seen = OracliRuntime.pop_value_last!(args1, ["--name"], false)
        @test seen == true
        @test v == "b"
        @test args1 == ["tail"]

        args2 = ["--name", ""]
        @test_throws OracliRuntime.ArgParseError OracliRuntime.pop_value!(args2, ["--name"], false)

        args3 = ["--name", ""]
        v3 = OracliRuntime.pop_value!(args3, ["--name"], true)
        @test v3 == ""

        args4 = ["--name", "--other"]
        @test_throws OracliRuntime.ArgParseError OracliRuntime.pop_value!(args4, ["--name"], true)
    end

    @testset "parse generic fallback branch" begin
        struct CtorOnlyType
            x::String
        end
        val = OracliRuntime.parse_value(CtorOnlyType, "abc", "k")
        @test val == CtorOnlyType("abc")

        struct BadType end
        @test_throws OracliRuntime.ArgParseError OracliRuntime.parse_value(BadType, "abc", "b")
    end

    @testset "convert_default error branch" begin
        @test_throws OracliRuntime.ArgParseError OracliRuntime.convert_default(Int, "x", "n")
    end

    @testset "locate_subcommand strict_unknown_option false path" begin
        sub_names = ["run"]
        needv = Set(["-p", "--port"])
        nov = Set(["-v"])
        s, i = OracliRuntime.locate_subcommand(["--unknown", "run"], sub_names, needv, nov; strict_unknown_option=false)
        @test s == "run"
        @test i == 2
    end

    @testset "locate_subcommand invalid bundle requiring value not last" begin
        sub_names = ["run"]
        needv = Set(["-p"])
        nov = Set(["-v", "-q"])
        @test_throws OracliRuntime.ArgParseError OracliRuntime.locate_subcommand(["-vpq", "1", "run"], sub_names, needv, nov)
    end
end

@CMD_MAIN EmptyValueCmd begin
    @ARG_REQ String name "--name"
end

@CMD_MAIN AllowExtraMainCmd begin
    @ALLOW_EXTRA
    @ARG_FLAG verbose "-v"
    @POS_REQ String src
end

@CMD_MAIN NoExtraMainCmd begin
    @ARG_FLAG verbose "-v"
    @POS_REQ String src
end

@CMD_MAIN AllowExtraSubCmd begin
    @ARG_FLAG g "-g"

    @CMD_SUB "open" begin
        @POS_REQ String target
        @ALLOW_EXTRA
    end

    @CMD_SUB "strict" begin
        @POS_REQ String target
    end
end

@CMD_MAIN HelpNameCmd begin
    @ARG_REQ Int port "-p" "--port" help="Port number" help_name="PORT"
    @POS_REQ String src help="Source file" help_name="SRC"
end

@testset "edge coverage: runtime behavior" begin
    @testset "allow_empty_option_value switch" begin
        @test_throws OracliRuntime.ArgParseError parse_cli(EmptyValueCmd, ["--name", ""])

        obj = parse_cli(EmptyValueCmd, ["--name", ""]; allow_empty_option_value=true)
        @test obj.name == ""
    end

    @testset "ALLOW_EXTRA in main command" begin
        obj = parse_cli(AllowExtraMainCmd, ["-v", "file.txt", "--unknown", "x", "y"])
        @test obj.verbose == true
        @test obj.src == "file.txt"

        @test_throws OracliRuntime.ArgParseError parse_cli(NoExtraMainCmd, ["file.txt", "--unknown"])
    end

    @testset "ALLOW_EXTRA in subcommand" begin
        obj1 = parse_cli(AllowExtraSubCmd, ["open", "t", "--x", "1", "y"])
        @test obj1.subcommand == "open"
        @test obj1.subcommand_args.target == "t"

        @test_throws OracliRuntime.ArgParseError parse_cli(AllowExtraSubCmd, ["strict", "t", "--x"])
    end

    @testset "help_name appears in help text" begin
        try
            parse_cli(HelpNameCmd, ["--help"])
            @test false
        catch e
            @test e isa OracliRuntime.ArgHelpRequested
            @test occursin("SRC", e.message)
        end
    end
end

@testset "edge coverage: run_cli and help template knobs" begin
    @testset "run_cli debug backtrace branch" begin
        out = IOBuffer()
        err = IOBuffer()
        code = run_cli(io=out, err_io=err, debug=true) do
            throw(ArgParseError("boom"))
        end
        @test code == 2
        msg = String(take!(err))
        @test occursin("Argument parsing error: boom", msg)
        @test occursin("debug backtrace", msg)
    end

    @testset "run_cli on_error for unexpected exception then rethrow" begin
        seen = Ref(false)
        @test_throws ErrorException run_cli(on_error = e -> (seen[] = e isa ErrorException)) do
            error("bad")
        end
        @test seen[] == true
    end
end
