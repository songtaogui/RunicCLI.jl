@testset "@ARG_GROUP help grouping" begin
    @CMD_MAIN GroupedCli begin
        @CMD_DESC "CLI with grouped help output"

        @ARG_FLAG verbose "-v" "--verbose" help="Verbose output"
        @ARG_OPT String config "--config" help="Config file"
        @POS_REQ String input help="Input path"
        @POS_OPT String output help="Output path"

        @ARG_GROUP "I/O Arguments" input output
        @ARG_GROUP "Runtime Options" verbose config
    end

    def = RunicCLIRuntime.clidef(GroupedCli)
    txt = render_help(def)

    @test occursin("Usage:", txt)
    @test occursin("I/O Arguments:", txt)
    @test occursin("Runtime Options:", txt)

    @test occursin("Input path", txt)
    @test occursin("Output path", txt)
    @test occursin("Verbose output", txt)
    @test occursin("Config file", txt)
end

@testset "@ARG_GROUP mixed grouped and ungrouped args" begin
    @CMD_MAIN PartiallyGroupedCli begin
        @CMD_DESC "CLI with partial grouping"

        @ARG_FLAG verbose "-v" "--verbose" help="Verbose output"
        @ARG_FLAG dryrun "--dry-run" help="Dry run"
        @ARG_OPT String config "--config" help="Config file"

        @POS_REQ String input help="Input path"
        @POS_OPT String output help="Output path"
        @POS_OPT String backup help="Backup path"

        @ARG_GROUP "I/O Group" input output
        @ARG_GROUP "Advanced" config
    end

    def = RunicCLIRuntime.clidef(PartiallyGroupedCli)
    txt = render_help(def)

    @test occursin("I/O Group:", txt)
    @test occursin("Advanced:", txt)

    @test occursin("Positional Arguments:", txt)
    @test occursin("Options:", txt)

    @test occursin("Backup path", txt)
    @test occursin("Verbose output", txt)
    @test occursin("Dry run", txt)

    @test occursin("Input path", txt)
    @test occursin("Output path", txt)
    @test occursin("Config file", txt)
end

@testset "@ARG_GROUP semantic validation" begin
    err1 = try
        @eval begin
            @CMD_MAIN GroupUnknownCli begin
                @ARG_FLAG verbose "-v"
                @ARG_GROUP "Bad Group" missingarg
            end
        end
        nothing
    catch e
        e
    end

    @test err1.error isa ArgumentError
    @test occursin("@ARG_GROUP", sprint(showerror, err1))
    @test occursin("unknown argument", sprint(showerror, err1))

    err2 = try
        @eval begin
            @CMD_MAIN GroupDuplicateCli begin
                @ARG_FLAG verbose "-v"
                @ARG_OPT String config "--config"
                @ARG_GROUP "First Group" verbose
                @ARG_GROUP "Second Group" verbose config
            end
        end
        nothing
    catch e
        e
    end

    @test err2.error isa ArgumentError
    @test occursin("@ARG_GROUP argument verbose is already assigned to group", sprint(showerror, err2))
end
