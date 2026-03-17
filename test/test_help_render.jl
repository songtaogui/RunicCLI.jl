using Test
using RunicCLI

@testset "help rendering templates" begin
    def = CliDef(
        cmd_name = "demo",
        description = "Demo command for help output.",
        epilog = "End of help.",
        args = ArgDef[
            ArgDef(kind=AK_POS_REQUIRED, name=:src, T=String, help="Source file"),
            ArgDef(kind=AK_OPTION, name=:port, T=Int, flags=["-p", "--port"], required=true, help="Port value"),
            ArgDef(kind=AK_FLAG, name=:verbose, T=Bool, flags=["-v", "--verbose"], help="Verbose mode"),
            ArgDef(kind=AK_OPTION_MULTI, name=:tag, T=String, flags=["-t", "--tag"], help="Tags")
        ],
        subcommands = SubcommandDef[
            SubcommandDef(name="run", description="Run job"),
            SubcommandDef(name="list", description="List jobs")
        ]
    )

    @testset "default template" begin
        txt = render_help(def)
        @test occursin("Usage:", txt)
        @test occursin("Positional Arguments:", txt)
        @test occursin("Option Arguments:", txt)
        @test occursin("Subcommands:", txt)
        @test occursin("Source file", txt)
        @test occursin("Port value", txt)
    end

    @testset "colored template and formatting overrides" begin
        tpl = build_help_template(
            style=HELP_COLORED,
            show_type=true,
            show_default=true,
            wrap_description=true,
            wrap_epilog=true,
            wrap_width=60
        )
        txt = render_help(def; template=tpl)
        @test occursin("\e[", txt)
        @test occursin("Usage:", txt)
    end

    @testset "fallback usage line" begin
        def2 = CliDef(cmd_name="app", args=ArgDef[
            ArgDef(kind=AK_FLAG, name=:v, T=Bool, flags=["-v"]),
            ArgDef(kind=AK_POS_REQUIRED, name=:x, T=String),
        ])
        txt2 = render_help(def2)
        @test occursin("app [OPTIONS] [ARGS...]", txt2)
    end
end
