@testset "arg_validator_file_index" begin
    mktempdir() do d
        f = joinpath(d, "sample.fa")
        open(f, "w") do io
            write(io, ">a\nACGT\n")
        end

        fai = f * ".fai"
        open(fai, "w") do io
            write(io, "idx")
        end

        @test validator_fn(V_file_has_index(suffixes=[".fai"], mode=:all))(f)
        @test validator_fn(V_file_has_any_index(suffixes=[".fai"]))(f)
        @test validator_fn(V_file_has_all_indexes(suffixes=[".fai"]))(f)

        @test !validator_fn(V_file_has_index(suffixes=[".csi"], mode=:all))(f)
        @test validator_fn(V_file_has_index(suffixes=[".csi"], mode=:none))(f)

        g = joinpath(d, "a.b.c.txt")
        open(g, "w") do io
            write(io, "x")
        end
        gidx = joinpath(d, "a.idx")
        open(gidx, "w") do io
            write(io, "idx")
        end

        @test validator_fn(V_file_has_index(replace_ext=[".idx"], strip_all_ext=true, mode=:all))(g)

        groups = [
            (suffixes=[".fai"], mode=:all),
            (replace_ext=[".idx"], mode=:none),
        ]
        @test validator_fn(V_file_has_index_groups(groups, group_mode=:all))(f)
    end
end
