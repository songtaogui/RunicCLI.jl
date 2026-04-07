@CMD_MAIN VersionCmdForTest begin
    @CMD_USAGE "version-demo [OPTIONS] [SUBCOMMAND]"
    @CMD_DESC "Version test command"
    @CMD_VERSION "VersionCmdForTest 1.0.0"

    @ARG_FLAG verbose "-v" "--verbose" help="""
        test newlines in help msgs:
        - line2
        - line3
        - line4
        """

    @CMD_SUB "serve" begin
        @CMD_DESC "Serve subcommand"
        @CMD_VERSION "serve 2.3.4"
        @ARG_OPT Int port "-p" "--port"
    end
end

@testset "version flag behavior" begin
    @testset "main version by --version and -V" begin
        for argv in (["--version"], ["-V"])
            try
                parse_cli(VersionCmdForTest, argv)
                @test false
            catch e
                @test e isa RunicCLI.ArgHelpRequested
                @test occursin("VersionCmdForTest 1.0.0", e.message)
            end
        end
    end

    @testset "subcommand version" begin
        try
            parse_cli(VersionCmdForTest, ["serve", "--version"])
            @test false
        catch e
            @test e isa RunicCLI.ArgHelpRequested
            @test occursin("serve 2.3.4", e.message)
        end
    end

    @testset "subcommand version can be overridden by config key" begin
        try
            parse_cli(VersionCmdForTest, ["serve", "--version"]; config=Dict("serve.version" => "serve OVERRIDE"))
            @test false
        catch e
            @test e isa RunicCLI.ArgHelpRequested
            @test occursin("serve OVERRIDE", e.message)
        end
    end
end