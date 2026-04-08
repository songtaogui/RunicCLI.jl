@testset "arg_validator_str" begin
    @test validator_fn(V_str_len_min(2))("ab")
    @test !validator_fn(V_str_len_min(3))("ab")

    @test validator_fn(V_str_len_max(2))("ab")
    @test !validator_fn(V_str_len_max(1))("ab")

    @test validator_fn(V_str_len_eq(2))("ab")
    @test !validator_fn(V_str_len_eq(3))("ab")

    @test validator_fn(V_str_len_range(2, 4))("abc")
    @test !validator_fn(V_str_len_range(2, 4))("a")

    @test validator_fn(V_str_prefix("ab"))("abcd")
    @test !validator_fn(V_str_prefix("bc"))("abcd")

    @test validator_fn(V_str_suffix("cd"))("abcd")
    @test !validator_fn(V_str_suffix("ab"))("abcd")

    @test validator_fn(V_str_contains("bc"))("abcd")
    @test !validator_fn(V_str_contains("xx"))("abcd")

    @test validator_fn(V_str_substrof("abcdef"))("bcd")
    @test !validator_fn(V_str_substrof("abcdef"))("xyz")

    @test validator_fn(V_str_regex(r"^item-\d+$"))("item-9")
    @test !validator_fn(V_str_regex(r"^item-\d+$"))("item-x")

    @test validator_fn(V_str_nonempty())("x")
    @test !validator_fn(V_str_nonempty())("")

    @test validator_fn(V_str_empty())("")
    @test !validator_fn(V_str_empty())("x")

    @test validator_fn(V_str_ascii())("ABC123")
    @test !validator_fn(V_str_ascii())("你好")

    @test validator_fn(V_str_printable())("ABC ~!@#")
    @test !validator_fn(V_str_printable())("A\tB")

    @test validator_fn(V_str_nowhitespace())("abc")
    @test !validator_fn(V_str_nowhitespace())("a b")

    @test validator_fn(V_str_url())("http://example.com")
    @test validator_fn(V_str_url())("https://example.com")
    @test !validator_fn(V_str_url())("ftp://example.com")

    @test validator_fn(V_str_email())("a@b.com")
    @test !validator_fn(V_str_email())("invalid_email")

    @test validator_fn(V_str_uuid())("550e8400-e29b-41d4-a716-446655440000")
    @test !validator_fn(V_str_uuid())("not-uuid")

    @test validator_fn(V_str_lc())("abc")
    @test !validator_fn(V_str_lc())("Abc")

    @test validator_fn(V_str_uc())("ABC")
    @test !validator_fn(V_str_uc())("ABc")

    @test validator_fn(V_str_trimmed())("abc")
    @test !validator_fn(V_str_trimmed())(" abc ")
end
