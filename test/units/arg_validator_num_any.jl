@testset "arg_validator_num_any" begin
    @test validator_fn(V_num_min(3))(3)
    @test !validator_fn(V_num_min(3))(2)

    @test validator_fn(V_num_max(3))(3)
    @test !validator_fn(V_num_max(3))(4)

    @test validator_fn(V_num_range(1, 3))(2)
    @test validator_fn(V_num_range(1, 3))(1)
    @test !validator_fn(V_num_range(1, 3; closed=false))(1)

    @test validator_fn(V_num_positive())(1)
    @test !validator_fn(V_num_positive())(0)

    @test validator_fn(V_num_nonnegative())(0)
    @test !validator_fn(V_num_nonnegative())(-1)

    @test validator_fn(V_num_negative())(-1)
    @test !validator_fn(V_num_negative())(0)

    @test validator_fn(V_num_nonpositive())(0)
    @test !validator_fn(V_num_nonpositive())(1)

    @test validator_fn(V_num_nonzero())(1)
    @test !validator_fn(V_num_nonzero())(0)

    @test validator_fn(V_num_finite())(1.0)
    @test !validator_fn(V_num_finite())(Inf)

    @test validator_fn(V_num_notnan())(1.0)
    @test !validator_fn(V_num_notnan())(NaN)

    @test validator_fn(V_num_real())(1.0)
    @test !validator_fn(V_num_real())(1 + 2im)

    @test validator_fn(V_num_int())(3)
    @test validator_fn(V_num_int())(3.0)
    @test !validator_fn(V_num_int())(3.2)

    @test validator_fn(V_num_integer())(7)
    @test validator_fn(V_num_integer())(7.0)

    @test validator_fn(V_num_float())(1.2)
    @test !validator_fn(V_num_float())(1)

    @test validator_fn(V_num_percentage())(0)
    @test validator_fn(V_num_percentage())(100)
    @test !validator_fn(V_num_percentage())(101)

    @test validator_fn(V_num_gt(3))(4)
    @test !validator_fn(V_num_gt(3))(3)

    @test validator_fn(V_num_ge(3))(3)
    @test !validator_fn(V_num_ge(3))(2)

    @test validator_fn(V_num_lt(3))(2)
    @test !validator_fn(V_num_lt(3))(3)

    @test validator_fn(V_num_le(3))(3)
    @test !validator_fn(V_num_le(3))(4)

    @test validator_fn(V_any_oneof(["a", "b"]))("a")
    @test !validator_fn(V_any_oneof(["a", "b"]))("c")

    @test validator_fn(V_any_in([1, 2]))(2)
    @test !validator_fn(V_any_in([1, 2]))(3)

    @test validator_fn(V_any_notin([1, 2]))(3)
    @test !validator_fn(V_any_notin([1, 2]))(2)

    @test validator_fn(V_any_equal("x"))("x")
    @test !validator_fn(V_any_equal("x"))("y")

    @test validator_fn(V_any_notequal("x"))("y")
    @test !validator_fn(V_any_notequal("x"))("x")
end
