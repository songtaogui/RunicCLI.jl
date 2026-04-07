@testset "arg_validator_str" begin
    @test V_str_len_min(2)("ab")
    @test !V_str_len_min(3)("ab")

    @test V_str_len_max(2)("ab")
    @test !V_str_len_max(1)("ab")

    @test V_str_len_eq(2)("ab")
    @test !V_str_len_eq(3)("ab")

    @test V_str_len_range(2, 4)("abc")
    @test !V_str_len_range(2, 4)("a")

    @test V_str_prefix("ab")("abcd")
    @test !V_str_prefix("bc")("abcd")

    @test V_str_suffix("cd")("abcd")
    @test !V_str_suffix("ab")("abcd")

    @test V_str_contains("bc")("abcd")
    @test !V_str_contains("xx")("abcd")

    @test V_str_substrof("abcdef")("bcd")
    @test !V_str_substrof("abcdef")("xyz")

    @test V_str_regex(r"^item-\d+$")("item-9")
    @test !V_str_regex(r"^item-\d+$")("item-x")

    @test V_str_nonempty()("x")
    @test !V_str_nonempty()("")

    @test V_str_empty()("")
    @test !V_str_empty()("x")

    @test V_str_ascii()("ABC123")
    @test !V_str_ascii()("你好")

    @test V_str_printable()("ABC ~!@#")
    @test !V_str_printable()("A\tB")

    @test V_str_nowhitespace()("abc")
    @test !V_str_nowhitespace()("a b")

    @test V_str_url()("http://example.com")
    @test V_str_url()("https://example.com")
    @test !V_str_url()("ftp://example.com")

    @test V_str_email()("a@b.com")
    @test !V_str_email()("invalid_email")

    @test V_str_uuid()("550e8400-e29b-41d4-a716-446655440000")
    @test !V_str_uuid()("not-uuid")

    @test V_str_lc()("abc")
    @test !V_str_lc()("Abc")

    @test V_str_uc()("ABC")
    @test !V_str_uc()("ABc")

    @test V_str_trimmed()("abc")
    @test !V_str_trimmed()(" abc ")
end
