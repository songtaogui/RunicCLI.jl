@testset "arg_validator_cmd" begin
    @test V_cmd_inpath()("julia")
    @test !V_cmd_inpath()("definitely_nonexistent_command_12345")

    @test V_cmd_executable()("julia")
    @test !V_cmd_executable()("definitely_nonexistent_command_12345")

    v = VersionNumber("$(VERSION.major).$(VERSION.minor).$(VERSION.patch)")
    vreg = r"julia version (\d+\.\d+\.\d+)"

    @test V_cmd_version_ge(v; vcmd="--version", vreg=vreg)("julia")
    @test V_cmd_version_le(v; vcmd="--version", vreg=vreg)("julia")
    @test V_cmd_version_eq(v; vcmd="--version", vreg=vreg)("julia")

    @test !V_cmd_version_gt(v; vcmd="--version", vreg=vreg)("julia")
    @test !V_cmd_version_lt(v; vcmd="--version", vreg=vreg)("julia")

    @test !V_cmd_version_ge(v; vcmd="--version", vreg=vreg)("definitely_nonexistent_command_12345")
end
