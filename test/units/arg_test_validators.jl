@CMD_MAIN ValidatorCmdForTest begin
    @CMD_USAGE "validator [OPTIONS]"
    @CMD_DESC "Validator command for builtin validator tests."

    @ARG_REQ Int level "--level"
    @ARG_REQ String mode "--mode"
    @ARG_REQ String tag "--tag"
    @ARG_REQ String filepath "--filepath"
    @ARG_MULTI Int nums "--num"

    @ARG_TEST level v_and(v_min(1), v_max(10)) "level must be between 1 and 10"
    @ARG_TEST mode v_oneof(["fast", "slow"]) "mode must be fast or slow"
    @ARG_TEST tag v_regex(r"^item-\d+$") "tag must match item-<number>"
    @ARG_TEST filepath v_and(v_exists(), v_isfile(), v_readable()) "filepath must be a readable file"
    @ARG_STREAM nums v_range(0, 100) "each num must be in [0,100]"
end

@testset "builtin validators" begin
    mktemp() do path, io
        write(io, "hello\n")
        close(io)

        @testset "validator success" begin
            obj = parse_cli(
                ValidatorCmdForTest,
                ["--level", "5", "--mode", "fast", "--tag", "item-7", "--filepath", path, "--num", "1", "--num", "100"]
            )
            @test obj.level == 5
            @test obj.mode == "fast"
            @test obj.tag == "item-7"
            @test obj.filepath == path
            @test obj.nums == [1, 100]
        end

        @testset "v_min/v_max fail" begin
            @test_throws RunicCLI.ArgParseError parse_cli(
                ValidatorCmdForTest,
                ["--level", "0", "--mode", "fast", "--tag", "item-7", "--filepath", path]
            )
        end

        @testset "v_oneof fail" begin
            @test_throws RunicCLI.ArgParseError parse_cli(
                ValidatorCmdForTest,
                ["--level", "5", "--mode", "turbo", "--tag", "item-7", "--filepath", path]
            )
        end

        @testset "v_regex fail" begin
            @test_throws RunicCLI.ArgParseError parse_cli(
                ValidatorCmdForTest,
                ["--level", "5", "--mode", "fast", "--tag", "bad-tag", "--filepath", path]
            )
        end

        @testset "path validators fail" begin
            missing_path = path * ".missing"
            @test_throws RunicCLI.ArgParseError parse_cli(
                ValidatorCmdForTest,
                ["--level", "5", "--mode", "fast", "--tag", "item-7", "--filepath", missing_path]
            )
        end

        @testset "stream validator fail" begin
            @test_throws RunicCLI.ArgParseError parse_cli(
                ValidatorCmdForTest,
                ["--level", "5", "--mode", "fast", "--tag", "item-7", "--filepath", path, "--num", "-1"]
            )
        end
    end
end



