@CMD_MAIN ConstraintCmdForTest begin
    @CMD_USAGE "constraint [OPTIONS] INPUT"
    @CMD_DESC "Command used to test inclusion, requires, conflicts and help rendering."
    @CMD_EPILOG "Constraint command epilog."

    @ARG_REQ Int port "-p" "--port" help="Port value"
    @ARG_FLAG json "--json" help="Enable json mode"
    @ARG_FLAG yaml "--yaml" help="Enable yaml mode"
    @ARG_FLAG upload "--upload" help="Enable upload"
    @ARG_FLAG download "--download" help="Enable download"
    @ARG_FLAG force "--force" help="Force action"
    @ARG_FLAG dryrun "--dry-run" help="Dry run mode"

    @POS_REQ String input help="Input path"

    @GROUP_INCL json yaml
    @ARG_REQUIRES upload force dryrun
    @ARG_CONFLICTS download upload
end

@testset "constraint macros behavior" begin
    @testset "@GROUP_INCL success" begin
        obj = parse_cli(ConstraintCmdForTest, ["-p", "1", "--json", "input.txt"])
        @test obj.port == 1
        @test obj.json == true
        @test obj.yaml == false
        @test obj.input == "input.txt"
    end

    @testset "@GROUP_INCL failure when none provided" begin
        err = try
            parse_cli(ConstraintCmdForTest, ["-p", "1", "input.txt"])
            nothing
        catch e
            e
        end
        @test err isa RunicCLI.ArgParseError
        @test occursin("At least one of the following arguments must be provided", err.message)
        @test occursin("json", err.message)
        @test occursin("yaml", err.message)
    end

    @testset "@GROUP_INCL success when multiple provided" begin
        obj = parse_cli(ConstraintCmdForTest, ["-p", "1", "--json", "--yaml", "input.txt"])
        @test obj.json == true
        @test obj.yaml == true
    end

    @testset "@ARG_REQUIRES success with one target" begin
        obj = parse_cli(ConstraintCmdForTest, ["-p", "1", "--json", "--upload", "--force", "input.txt"])
        @test obj.upload == true
        @test obj.force == true
        @test obj.dryrun == false
    end

    @testset "@ARG_REQUIRES success with another target" begin
        obj = parse_cli(ConstraintCmdForTest, ["-p", "1", "--yaml", "--upload", "--dry-run", "input.txt"])
        @test obj.upload == true
        @test obj.force == false
        @test obj.dryrun == true
    end

    @testset "@ARG_REQUIRES failure" begin
        err = try
            parse_cli(ConstraintCmdForTest, ["-p", "1", "--json", "--upload", "input.txt"])
            nothing
        catch e
            e
        end
        @test err isa RunicCLI.ArgParseError
        @test occursin("requires at least one of", err.message)
        @test occursin("upload", err.message)
        @test occursin("force", err.message)
        @test occursin("dryrun", err.message)
    end

    @testset "@ARG_CONFLICTS success" begin
        obj = parse_cli(ConstraintCmdForTest, ["-p", "1", "--json", "--download", "input.txt"])
        @test obj.download == true
        @test obj.upload == false
    end

    @testset "@ARG_CONFLICTS failure" begin
        err = try
            parse_cli(ConstraintCmdForTest, ["-p", "1", "--json", "--download", "--upload", "--force", "input.txt"])
            nothing
        catch e
            e
        end
        @test err isa RunicCLI.ArgParseError
        @test occursin("conflicts with", err.message)
        @test occursin("download", err.message)
        @test occursin("upload", err.message)
    end

    @testset "help rendering contains constraints section" begin
        try
            parse_cli(ConstraintCmdForTest, ["--help"])
            @test false
        catch e
            @test e isa RunicCLI.ArgHelpRequested
            @test occursin("Constraints:", e.message)
            @test occursin("At least one required: json, yaml", e.message)
            @test occursin("upload requires one of: force, dryrun", e.message)
            @test occursin("download conflicts with: upload", e.message)
        end
    end

    @testset "help rendering can be disabled" begin
        try
            parse_cli(ConstraintCmdForTest, ["--help"]; help=HelpTemplateOptions(show_constraints=false))
            @test false
        catch e
            @test e isa RunicCLI.ArgHelpRequested
            @test !occursin("Constraints:", e.message)
            @test !occursin("At least one required: json, yaml", e.message)
            @test !occursin("upload requires one of: force, dryrun", e.message)
            @test !occursin("download conflicts with: upload", e.message)
        end
    end

    @testset "render_help direct call contains constraints section" begin
        def = CliDef(
            cmd_name = "constraint",
            usage = "constraint [OPTIONS] INPUT",
            description = "Command used to test inclusion, requires, conflicts and help rendering.",
            epilog = "Constraint command epilog.",
            args = ArgDef[
                ArgDef(kind=AK_OPTION, name=:port, T=Int, flags=["-p", "--port"], required=true, help="Port value"),
                ArgDef(kind=AK_FLAG, name=:json, T=Bool, flags=["--json"], help="Enable json mode"),
                ArgDef(kind=AK_FLAG, name=:yaml, T=Bool, flags=["--yaml"], help="Enable yaml mode"),
                ArgDef(kind=AK_FLAG, name=:upload, T=Bool, flags=["--upload"], help="Enable upload"),
                ArgDef(kind=AK_FLAG, name=:download, T=Bool, flags=["--download"], help="Enable download"),
                ArgDef(kind=AK_FLAG, name=:force, T=Bool, flags=["--force"], help="Force action"),
                ArgDef(kind=AK_FLAG, name=:dryrun, T=Bool, flags=["--dry-run"], help="Dry run mode"),
                ArgDef(kind=AK_POS_REQUIRED, name=:input, T=String, required=true, help="Input path")
            ],
            mutual_inclusion_groups = [[:json, :yaml]],
            arg_requires = [ArgRequiresDef(anchor=:upload, targets=[:force, :dryrun])],
            arg_conflicts = [ArgConflictsDef(anchor=:download, targets=[:upload])]
        )

        msg = render_help(def)
        @test occursin("Constraints:", msg)
        @test occursin("At least one required: json, yaml", msg)
        @test occursin("upload requires one of: force, dryrun", msg)
        @test occursin("download conflicts with: upload", msg)
    end
end
