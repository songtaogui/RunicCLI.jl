@testset "arg_validator_path_file_dir" begin
    mktempdir() do d
        f = joinpath(d, "a.txt")
        open(f, "w") do io
            write(io, "hello")
        end

        emptyf = joinpath(d, "empty.txt")
        open(emptyf, "w") do io
            write(io, "")
        end

        @test V_path_exists()(f)
        @test !V_path_exists()(joinpath(d, "missing.txt"))

        @test V_path_absent()(joinpath(d, "missing.txt"))
        @test !V_path_absent()(f)

        @test V_path_isfile()(f)
        @test !V_path_isfile()(d)

        @test V_path_isdir()(d)
        @test !V_path_isdir()(f)

        @test V_path_readable()(f)
        @test V_path_writable()(f)

        julia_path = joinpath(Sys.BINDIR, Base.julia_exename())
        @test V_path_executable()(julia_path)

        @test V_path_absolute()(abspath(f))
        @test V_path_relative()("relative/path.txt")
        @test !V_path_relative()(abspath(f))

        @test V_path_nottraversal()("a/b/c.txt")
        @test !V_path_nottraversal()("../a.txt")

        @test V_path_ext(".txt")(f)
        @test !V_path_ext(".toml")(f)

        @test V_file_readable()(f)
        @test V_file_writable()(f)

        @test V_file_creatable()(joinpath(d, "newfile.txt"))
        @test !V_file_creatable()(joinpath(d, "missing_dir", "newfile.txt"))

        @test V_file_nonempty()(f)
        @test !V_file_nonempty()(emptyf)

        @test V_dir_readable()(d)
        @test V_dir_writable()(d)

        subdir = joinpath(d, "sub")
        mkpath(subdir)
        inside = joinpath(subdir, "in.txt")
        open(inside, "w") do io
            write(io, "x")
        end
        @test V_path_within(d)(inside)

        mktempdir() do d2
            outside = joinpath(d2, "out.txt")
            open(outside, "w") do io
                write(io, "x")
            end
            @test !V_path_within(d)(outside)
        end

        linkp = joinpath(d, "alink")
        symlink_supported = true
        try
            symlink(f, linkp)
        catch
            symlink_supported = false
        end
        if symlink_supported
            @test V_path_symlink()(linkp)
        end
    end
end
