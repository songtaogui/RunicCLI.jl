using Test
using Oracli

@CMD_MAIN ConstraintCmdForTest begin
    @CMD_USAGE "constraint [OPTIONS] INPUT"
    @CMD_DESC "Command used to test argument relations and help rendering."
    @CMD_EPILOG "Constraint command epilog."

    @ARG_REQ Int port "-p" "--port" help="Port value"
    @ARG_FLAG json "--json" help="Enable json mode"
    @ARG_FLAG yaml "--yaml" help="Enable yaml mode"
    @ARG_FLAG upload "--upload" help="Enable upload"
    @ARG_FLAG download "--download" help="Enable download"
    @ARG_FLAG force "--force" help="Force action"
    @ARG_FLAG dryrun "--dry-run" help="Dry run mode"
    @ARG_FLAG alpha "--alpha" help="Enable alpha"
    @ARG_FLAG beta "--beta" help="Enable beta"
    @ARG_FLAG cert "--cert" help="Certificate path toggle"
    @ARG_FLAG key "--key" help="Private key path toggle"

    @POS_REQ String input help="Input path"

    @ARGREL_ATLEASTONE json yaml help="one of json or yaml must be provided"
    @ARGREL_DEPENDS all(upload) any(force, dryrun) help="upload requires force or dryrun"
    @ARGREL_CONFLICTS download upload help="download cannot be combined with upload"
    @ARGREL_ONLYONE alpha beta help="exactly one of alpha or beta must be provided"
    @ARGREL_ALLORNONE cert key help="cert and key must be provided together"
end

@testset "constraint macros behavior" begin
    @testset "@ARGREL_ATLEASTONE success" begin
        obj = parse_cli(ConstraintCmdForTest, ["-p", "1", "--json", "--alpha", "input.txt"])
        @test obj.port == 1
        @test obj.json == true
        @test obj.yaml == false
        @test obj.alpha == true
        @test obj.beta == false
        @test obj.input == "input.txt"
    end

    @testset "@ARGREL_ATLEASTONE failure when none provided" begin
        err = try
            parse_cli(ConstraintCmdForTest, ["-p", "1", "--alpha", "input.txt"])
            nothing
        catch e
            e
        end

        @test err isa Oracli.ArgParseError
        @test occursin("one of json or yaml must be provided", err.message)
    end

    @testset "@ARGREL_ATLEASTONE success when multiple provided" begin
        obj = parse_cli(ConstraintCmdForTest, ["-p", "1", "--json", "--yaml", "--alpha", "input.txt"])
        @test obj.json == true
        @test obj.yaml == true
    end

    @testset "@ARGREL_DEPENDS success with one target" begin
        obj = parse_cli(ConstraintCmdForTest, ["-p", "1", "--json", "--upload", "--force", "--alpha", "input.txt"])
        @test obj.upload == true
        @test obj.force == true
        @test obj.dryrun == false
    end

    @testset "@ARGREL_DEPENDS success with another target" begin
        obj = parse_cli(ConstraintCmdForTest, ["-p", "1", "--yaml", "--upload", "--dry-run", "--alpha", "input.txt"])
        @test obj.upload == true
        @test obj.force == false
        @test obj.dryrun == true
    end

    @testset "@ARGREL_DEPENDS failure" begin
        err = try
            parse_cli(ConstraintCmdForTest, ["-p", "1", "--json", "--upload", "--alpha", "input.txt"])
            nothing
        catch e
            e
        end

        @test err isa Oracli.ArgParseError
        @test occursin("upload requires force or dryrun", err.message)
    end

    @testset "@ARGREL_CONFLICTS success" begin
        obj = parse_cli(ConstraintCmdForTest, ["-p", "1", "--json", "--download", "--alpha", "input.txt"])
        @test obj.download == true
        @test obj.upload == false
    end

    @testset "@ARGREL_CONFLICTS failure" begin
        err = try
            parse_cli(ConstraintCmdForTest, ["-p", "1", "--json", "--download", "--upload", "--force", "--alpha", "input.txt"])
            nothing
        catch e
            e
        end

        @test err isa Oracli.ArgParseError
        @test occursin("download cannot be combined with upload", err.message)
    end

    @testset "@ARGREL_ONLYONE success with alpha" begin
        obj = parse_cli(ConstraintCmdForTest, ["-p", "1", "--json", "--alpha", "input.txt"])
        @test obj.alpha == true
        @test obj.beta == false
    end

    @testset "@ARGREL_ONLYONE success with beta" begin
        obj = parse_cli(ConstraintCmdForTest, ["-p", "1", "--json", "--beta", "input.txt"])
        @test obj.alpha == false
        @test obj.beta == true
    end

    @testset "@ARGREL_ONLYONE failure when none provided" begin
        err = try
            parse_cli(ConstraintCmdForTest, ["-p", "1", "--json", "input.txt"])
            nothing
        catch e
            e
        end

        @test err isa Oracli.ArgParseError
        @test occursin("exactly one of alpha or beta must be provided", err.message)
    end

    @testset "@ARGREL_ONLYONE failure when both provided" begin
        err = try
            parse_cli(ConstraintCmdForTest, ["-p", "1", "--json", "--alpha", "--beta", "input.txt"])
            nothing
        catch e
            e
        end

        @test err isa Oracli.ArgParseError
        @test occursin("exactly one of alpha or beta must be provided", err.message)
    end

    @testset "@ARGREL_ALLORNONE success with none provided" begin
        obj = parse_cli(ConstraintCmdForTest, ["-p", "1", "--json", "--alpha", "input.txt"])
        @test obj.cert == false
        @test obj.key == false
    end

    @testset "@ARGREL_ALLORNONE success with both provided" begin
        obj = parse_cli(ConstraintCmdForTest, ["-p", "1", "--json", "--alpha", "--cert", "--key", "input.txt"])
        @test obj.cert == true
        @test obj.key == true
    end

    @testset "@ARGREL_ALLORNONE failure with only one provided" begin
        err1 = try
            parse_cli(ConstraintCmdForTest, ["-p", "1", "--json", "--alpha", "--cert", "input.txt"])
            nothing
        catch e
            e
        end

        @test err1 isa Oracli.ArgParseError
        @test occursin("cert and key must be provided together", err1.message)

        err2 = try
            parse_cli(ConstraintCmdForTest, ["-p", "1", "--json", "--alpha", "--key", "input.txt"])
            nothing
        catch e
            e
        end

        @test err2 isa Oracli.ArgParseError
        @test occursin("cert and key must be provided together", err2.message)
    end

    @testset "help rendering contains constraints section" begin
        try
            parse_cli(ConstraintCmdForTest, ["--help"])
            @test false
        catch e
            @test e isa Oracli.ArgHelpRequested
            @test occursin("Constraints:", e.message)
            @test occursin("json", e.message)
            @test occursin("yaml", e.message)
            @test occursin("upload", e.message)
            @test occursin("force", e.message)
            @test occursin("dryrun", e.message)
            @test occursin("download", e.message)
            @test occursin("alpha", e.message)
            @test occursin("beta", e.message)
            @test occursin("cert", e.message)
            @test occursin("key", e.message)
        end
    end

    @testset "help rendering can be disabled" begin
        try
            parse_cli(ConstraintCmdForTest, ["--help"]; help=HelpTemplateOptions(show_constraints=false))
            @test false
        catch e
            @test e isa Oracli.ArgHelpRequested
            @test !occursin("Constraints:", e.message)
        end
    end

    @testset "render_help direct call contains constraints section" begin
        def = CliDef(
            cmd_name = "constraint",
            usage = "constraint [OPTIONS] INPUT",
            description = "Command used to test argument relations and help rendering.",
            epilog = "Constraint command epilog.",
            version = "",
            args = ArgDef[
                ArgDef(kind=AK_OPTION, name=:port, T=Int, flags=["-p", "--port"], required=true, help="Port value"),
                ArgDef(kind=AK_FLAG, name=:json, T=Bool, flags=["--json"], help="Enable json mode"),
                ArgDef(kind=AK_FLAG, name=:yaml, T=Bool, flags=["--yaml"], help="Enable yaml mode"),
                ArgDef(kind=AK_FLAG, name=:upload, T=Bool, flags=["--upload"], help="Enable upload"),
                ArgDef(kind=AK_FLAG, name=:download, T=Bool, flags=["--download"], help="Enable download"),
                ArgDef(kind=AK_FLAG, name=:force, T=Bool, flags=["--force"], help="Force action"),
                ArgDef(kind=AK_FLAG, name=:dryrun, T=Bool, flags=["--dry-run"], help="Dry run mode"),
                ArgDef(kind=AK_FLAG, name=:alpha, T=Bool, flags=["--alpha"], help="Enable alpha"),
                ArgDef(kind=AK_FLAG, name=:beta, T=Bool, flags=["--beta"], help="Enable beta"),
                ArgDef(kind=AK_FLAG, name=:cert, T=Bool, flags=["--cert"], help="Certificate path toggle"),
                ArgDef(kind=AK_FLAG, name=:key, T=Bool, flags=["--key"], help="Private key path toggle"),
                ArgDef(kind=AK_POS_REQUIRED, name=:input, T=String, required=true, help="Input path")
            ],
            subcommands = SubcommandDef[],
            allow_extra = false,
            auto_help = false,
            relations = ArgRelationDef[
                ArgRelationDef(kind=:atleastone, members=[:json, :yaml], help="one of json or yaml must be provided"),
                ArgRelationDef(
                    kind=:depends,
                    lhs=RelAll(members=[:upload]),
                    rhs=RelAny(members=[:force, :dryrun]),
                    help="upload requires force or dryrun"
                ),
                ArgRelationDef(
                    kind=:conflicts,
                    lhs=RelAll(members=[:download]),
                    rhs=RelAny(members=[:upload]),
                    help="download cannot be combined with upload"
                ),
                ArgRelationDef(kind=:onlyone, members=[:alpha, :beta], help="exactly one of alpha or beta must be provided"),
                ArgRelationDef(kind=:allornone, members=[:cert, :key], help="cert and key must be provided together")
            ],
            arg_groups = ArgGroupDef[]
        )

        msg = render_help(def)
        @test occursin("Constraints:", msg)
        @test occursin("json", msg)
        @test occursin("yaml", msg)
        @test occursin("upload", msg)
        @test occursin("force", msg)
        @test occursin("dryrun", msg)
        @test occursin("download", msg)
        @test occursin("alpha", msg)
        @test occursin("beta", msg)
        @test occursin("cert", msg)
        @test occursin("key", msg)
    end
end
