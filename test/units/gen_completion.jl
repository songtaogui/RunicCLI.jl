
@testset "completion generation" begin
    def = CliDef(
        cmd_name = "mytool",
        args = ArgDef[
            ArgDef(kind=AK_FLAG, name=:verbose, T=Bool, flags=["-v", "--verbose"]),
            ArgDef(kind=AK_OPTION, name=:port, T=Int, flags=["-p", "--port"])
        ],
        subcommands = SubcommandDef[
            SubcommandDef(
                name="serve",
                args=ArgDef[
                    ArgDef(kind=AK_FLAG, name=:dryrun, T=Bool, flags=["--dry-run"])
                ]
            )
        ]
    )

    fish = generate_completion(def; shell=:fish, prog="mytool")
    @test occursin("complete -c mytool -l verbose", fish)
    @test occursin("complete -c mytool -s v", fish)
    @test occursin("complete -c mytool -l port", fish)
    @test occursin("complete -c mytool -a 'serve'", fish)

    @test_throws ArgumentError generate_completion(def; shell=:powershell, prog="mytool")
end
