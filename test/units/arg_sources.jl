@CMD_MAIN SourceMergeCmdForTest begin
    @CMD_USAGE "source-merge [OPTIONS]"
    @CMD_DESC "Source merge behavior test"

    @ARG_OPT String host "--host"
    @ARG_FLAG debug "--debug"
    @ARG_COUNT quiet "-q" "--quiet"
end

@testset "env/config/cli source merging priority" begin
    env = Dict(
        "APP_HOST" => "env-host",
        "APP_DEBUG" => true,
        "APP_QUIET" => 1
    )
    cfg = Dict(
        "host" => "cfg-host",
        "debug" => false,
        "quiet" => 2
    )

    @testset "config overrides env when cli missing" begin
        obj = parse_cli(
            SourceMergeCmdForTest,
            String[];
            env_prefix="APP_",
            env=env,
            config=cfg
        )
        @test obj.host == "cfg-host"
        @test obj.debug == false
        @test obj.quiet == 2
    end

    @testset "cli overrides both config and env" begin
        obj = parse_cli(
            SourceMergeCmdForTest,
            ["--host", "cli-host", "--debug", "-q"];
            env_prefix="APP_",
            env=env,
            config=cfg
        )
        @test obj.host == "cli-host"
        @test obj.debug == true
        @test obj.quiet == 1
    end

    @testset "config file TOML is loaded" begin
        mktempdir() do dir
            cfgpath = joinpath(dir, "app.toml")
            write(cfgpath, """
host = "toml-host"
debug = true
quiet = 3
""")
            obj = parse_cli(
                SourceMergeCmdForTest,
                String[];
                config_file=cfgpath
            )
            @test obj.host == "toml-host"
            @test obj.debug == true
            @test obj.quiet == 3
        end
    end
end