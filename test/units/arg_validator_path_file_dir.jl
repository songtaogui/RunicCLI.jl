@testset "arg_validator_path_file_dir" begin
    mktempdir() do d
        # ---------- fixtures ----------
        f = joinpath(d, "a.txt")
        open(f, "w") do io
            write(io, "hello\nworld\n")
        end

        emptyf = joinpath(d, "empty.txt")
        open(emptyf, "w") do io
            write(io, "")
        end

        subdir = joinpath(d, "sub")
        mkpath(subdir)
        inside = joinpath(subdir, "in.txt")
        open(inside, "w") do io
            write(io, "x")
        end

        emptydir = joinpath(d, "emptydir")
        mkpath(emptydir)

        # ---------- path ----------
        @test validator_fn(V_path_exists())(f)
        @test !validator_fn(V_path_exists())(joinpath(d, "missing.txt"))

        @test validator_fn(V_path_absent())(joinpath(d, "missing.txt"))
        @test !validator_fn(V_path_absent())(f)

        @test validator_fn(V_path_isfile())(f)
        @test !validator_fn(V_path_isfile())(d)

        @test validator_fn(V_path_isdir())(d)
        @test !validator_fn(V_path_isdir())(f)

        @test validator_fn(V_path_readable())(f)
        @test validator_fn(V_path_writable())(f)

        julia_path = joinpath(Sys.BINDIR, Base.julia_exename())
        @test validator_fn(V_path_executable())(julia_path)

        @test validator_fn(V_path_absolute())(abspath(f))
        @test validator_fn(V_path_relative())("relative/path.txt")
        @test !validator_fn(V_path_relative())(abspath(f))

        @test validator_fn(V_path_nottraversal())("a/b/c.txt")
        @test !validator_fn(V_path_nottraversal())("../a.txt")

        @test validator_fn(V_path_real())(abspath(f))

        @test validator_fn(V_path_nonblank())("abc")
        @test !validator_fn(V_path_nonblank())("   ")

        @test validator_fn(V_path_ext_in(".txt"))(f)
        @test validator_fn(V_path_ext_in("txt", "md"))(f)
        @test !validator_fn(V_path_ext_in(".toml"))(f)

        @test validator_fn(V_path_basename_match(r"^a\.(txt|md)$"))(f)
        @test !validator_fn(V_path_basename_match(r"^b\.txt$"))(f)

        @test validator_fn(V_path_basename_only())("name.txt")
        @test !validator_fn(V_path_basename_only())("a/b.txt")
        @test !validator_fn(V_path_basename_only())("..")

        @test validator_fn(V_path_maxlen(1024))(f)
        @test !validator_fn(V_path_maxlen(1))(f)

        @test validator_fn(V_path_within(d))(inside)
        mktempdir() do d2
            outside = joinpath(d2, "out.txt")
            open(outside, "w") do io
                write(io, "x")
            end
            @test !validator_fn(V_path_within(d))(outside)
        end

        # symlink / nosymlink
        linkp = joinpath(d, "alink")
        symlink_supported = true
        try
            symlink(f, linkp)
        catch
            symlink_supported = false
        end
        if symlink_supported
            @test validator_fn(V_path_symlink())(linkp)
            @test !validator_fn(V_path_nosymlink())(linkp)
        end
        @test validator_fn(V_path_nosymlink())(f)

        # ---------- file ----------
        @test validator_fn(V_file_readable())(f)
        @test validator_fn(V_file_writable())(f)
        @test validator_fn(V_file_executable())(julia_path)

        @test validator_fn(V_file_creatable())(joinpath(d, "newfile.txt"))
        @test !validator_fn(V_file_creatable())(joinpath(d, "missing_dir", "newfile.txt"))

        @test validator_fn(V_file_output_safe())(joinpath(d, "new_out.txt"))
        @test validator_fn(V_file_output_safe())(f)
        @test !validator_fn(V_file_output_safe())(d)

        @test validator_fn(V_file_nonempty())(f)
        @test !validator_fn(V_file_nonempty())(emptyf)

        @test validator_fn(V_file_empty())(emptyf)
        @test !validator_fn(V_file_empty())(f)

        @test validator_fn(V_file_size_between(1, 10_000))(f)
        @test !validator_fn(V_file_size_between(1, 2))(f)
        @test !validator_fn(V_file_size_between(-1, 10))(f)

        @test validator_fn(V_file_linecount_between(2, 2))(f)
        @test validator_fn(V_file_linecount_between(0, 0))(emptyf)
        @test !validator_fn(V_file_linecount_between(3, 5))(f)

        @test validator_fn(V_file_newer_than(0))(f)
        @test !validator_fn(V_file_older_than(0))(f)

        @test validator_fn(V_file_newer_than(DateTime(2000, 1, 1)))(f)
        @test validator_fn(V_file_older_than(DateTime(2100, 1, 1)))(f)

        # ---------- dir ----------
        @test validator_fn(V_dir_readable())(d)
        @test validator_fn(V_dir_writable())(d)

        @test validator_fn(V_dir_contains("a.txt"))(d)
        @test validator_fn(V_dir_contains(["a.txt", "empty.txt"]; kind=:file, require_all=true))(d)
        @test validator_fn(V_dir_contains(["sub"]; kind=:subdir, require_all=true))(d)
        @test !validator_fn(V_dir_contains("not_exist.txt"))(d)

        @test validator_fn(V_dir_contains_glob("*.txt"; min_count=2, max_count=10, recursive=false))(d)
        @test !validator_fn(V_dir_contains_glob("*.txt"; min_count=3, max_count=10, recursive=false))(subdir)
        @test validator_fn(V_dir_contains_glob("sub/*.txt"; min_count=1, max_count=2, recursive=true))(d)

        @test validator_fn(V_dir_creatable())(d)
        @test validator_fn(V_dir_creatable())(joinpath(d, "new_subdir"))
        @test !validator_fn(V_dir_creatable())(joinpath(d, "missing_parent", "new_subdir"))

        @test validator_fn(V_dir_empty())(emptydir)
        @test !validator_fn(V_dir_empty())(d)

        @test validator_fn(V_dir_nonempty())(d)
        @test !validator_fn(V_dir_nonempty())(emptydir)
    end
end
