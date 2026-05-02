@CMD_MAIN ValidatorCmdForTest begin
    @CMD_USAGE "validator [OPTIONS]"
    @CMD_DESC "Validator command for builtin validator tests."

    @ARG_REQ Int level "--level" vfun=V_num_min(1)
    @ARG_REQ String mode "--mode" vfun=V_any_oneof(["fast", "slow"])
    @ARG_REQ String tag "--tag" vfun=V_str_regex(r"^item-\d+$")
    @ARG_REQ String filepath "--filepath" vfun=V_AND(V_path_exists(), V_path_isfile(), V_path_readable())
    @ARG_MULTI Int nums "--num" vfun=V_num_range(0, 100)

    @ARG_TEST level mode tag vfun=x -> !isnothing(x) vmsg="level/mode/tag should not be nothing"
end

@CMD_MAIN ValidatorCmdForArgTestMulti begin
    @CMD_USAGE "validator-multi [OPTIONS]"
    @CMD_DESC "Validator command for @ARG_TEST multi-arg validation tests."

    @ARG_REQ Int level "--level"
    @ARG_REQ String mode "--mode"
    @ARG_REQ String tag "--tag"

    @ARG_TEST level mode tag vfun = x -> begin
        if x isa Int
            return x >= 1
        elseif x isa String
            return !isempty(strip(x))
        else
            return false
        end
    end vmsg="multi-arg validator failed"
end

@testset "arg_validator_cli_integration" begin
    mktemp() do path, io
        write(io, "hello\n")
        close(io)

        obj = parse_cli(ValidatorCmdForTest,
            ["--level", "5", "--mode", "fast", "--tag", "item-7", "--filepath", path, "--num", "1", "--num", "100"])
        @test obj.level == 5
        @test obj.mode == "fast"
        @test obj.tag == "item-7"
        @test obj.filepath == path
        @test obj.nums == [1, 100]

        @test_throws Oracli.ArgParseError parse_cli(
            ValidatorCmdForTest,
            ["--level", "0", "--mode", "fast", "--tag", "item-7", "--filepath", path]
        )

        @test_throws Oracli.ArgParseError parse_cli(
            ValidatorCmdForTest,
            ["--level", "5", "--mode", "turbo", "--tag", "item-7", "--filepath", path]
        )

        @test_throws Oracli.ArgParseError parse_cli(
            ValidatorCmdForTest,
            ["--level", "5", "--mode", "fast", "--tag", "bad-tag", "--filepath", path]
        )

        @test_throws Oracli.ArgParseError parse_cli(
            ValidatorCmdForTest,
            ["--level", "5", "--mode", "fast", "--tag", "item-7", "--filepath", path * ".missing"]
        )

        @test_throws Oracli.ArgParseError parse_cli(
            ValidatorCmdForTest,
            ["--level", "5", "--mode", "fast", "--tag", "item-7", "--filepath", path, "--num", "-1"]
        )
    end

    obj = parse_cli(
        ValidatorCmdForArgTestMulti,
        ["--level", "3", "--mode", "fast", "--tag", "item-1"]
    )
    @test obj.level == 3
    @test obj.mode == "fast"
    @test obj.tag == "item-1"

    @test_throws Oracli.ArgParseError parse_cli(
        ValidatorCmdForArgTestMulti,
        ["--level", "0", "--mode", "fast", "--tag", "item-1"]
    )

    @test_throws Oracli.ArgParseError parse_cli(
        ValidatorCmdForArgTestMulti,
        ["--level", "3", "--mode", "   ", "--tag", "item-1"]
    )

    @test_throws Oracli.ArgParseError parse_cli(
        ValidatorCmdForArgTestMulti,
        ["--level", "3", "--mode", "fast", "--tag", ""]
    )
end
