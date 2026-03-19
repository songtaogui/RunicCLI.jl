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

        @test occursin("Demo command for help output.", txt)
        @test occursin("End of help.", txt)

        @test occursin("Source file", txt)
        @test occursin("Port value", txt)
        @test occursin("Verbose mode", txt)
        @test occursin("Tags", txt)

        @test occursin("run", txt)
        @test occursin("Run job", txt)
        @test occursin("list", txt)
        @test occursin("List jobs", txt)

        @test !occursin("\e[", txt)
    end

    @testset "colored template" begin
        tpl = build_help_template(
            style = HELP_COLORED
        )
        txt = render_help(def; template=tpl)

        @test occursin("\e[", txt)
        @test occursin("Usage:", txt)
        @test occursin("Positional Arguments:", txt)
        @test occursin("Option Arguments:", txt)
    end

    @testset "fallback usage line" begin
        def2 = CliDef(
            cmd_name = "app",
            args = ArgDef[
                ArgDef(kind=AK_FLAG, name=:v, T=Bool, flags=["-v"]),
                ArgDef(kind=AK_POS_REQUIRED, name=:x, T=String),
            ]
        )

        txt2 = render_help(def2)
        @test occursin("app [OPTIONS] [ARGS...]", txt2)
    end

    @testset "fallback usage with subcommands" begin
        def3 = CliDef(
            cmd_name = "tool",
            args = ArgDef[
                ArgDef(kind=AK_FLAG, name=:verbose, T=Bool, flags=["-v", "--verbose"])
            ],
            subcommands = SubcommandDef[
                SubcommandDef(name="run", description="Run")
            ]
        )

        txt3 = render_help(def3)
        @test occursin("tool [OPTIONS] [SUBCOMMAND]", txt3)
    end

    @testset "classic formatting overrides" begin
        fmt = HelpFormatOptions(
            required_style = HLS_HIDDEN,
            default_style = HLS_HIDDEN,
            type_style = HLS_HIDDEN,
            count_style = HLS_HIDDEN,
            show_option_metavar = false,
            wrap_description = true,
            wrap_epilog = true,
            wrap_width = 40,
        )

        tpl = build_help_template(
            style = HELP_PLAIN,
            format = fmt,
            indent_item = 4,
            indent_text = 8,
            section_gap = false,
            title_usage = "USAGE:",
            title_options = "OPTIONS:",
            title_subcommands = "CMDS:"
        )

        txt = render_help(def; template=tpl)

        @test occursin("USAGE:", txt)
        @test occursin("OPTIONS:", txt)
        @test occursin("CMDS:", txt)

        @test !occursin("Type:", txt)
        @test !occursin("Required", txt)
        @test !occursin("Default", txt)

        @test occursin("-p, --port", txt)
        @test !occursin("<port>", lowercase(txt))
    end

    @testset "inline item help and inline meta" begin
        tpl = build_help_template(
            style = HELP_PLAIN,
            wrap_width = 100
        )

        txt = render_help(def; template=tpl)

        @test occursin("src::String", txt)
        @test occursin("<port>::Int", txt)
        @test occursin("<tag>::Vector{String}", txt)
        @test occursin("Source file", txt)
        @test occursin("Port value", txt)
        @test occursin("Required", txt)
    end

    @testset "default value metadata rendering" begin
        def2 = CliDef(
            cmd_name = "demo",
            args = ArgDef[
                ArgDef(kind=AK_POS_DEFAULT, name=:mode, T=String, default="fast", help="Mode"),
                ArgDef(kind=AK_OPTION, name=:port, T=Int, flags=["-p", "--port"], default=8080, required=false, help="Port")
            ]
        )

        txt = render_help(def2)

        @test occursin("Default", txt)
        @test occursin("Default: \"fast\"", txt) || occursin("Default: fast", txt)
        @test occursin("Default: 8080", txt)
    end

    @testset "count metadata rendering" begin
        def2 = CliDef(
            cmd_name = "demo",
            args = ArgDef[
                ArgDef(kind=AK_COUNT, name=:verbose, T=Int, flags=["-v", "--verbose"], help="Increase verbosity")
            ]
        )

        txt = render_help(def2)

        @test occursin("Increase verbosity", txt)
        @test occursin("Count of -v", txt)
    end

    @testset "show_option_metavar toggle" begin
        def2 = CliDef(
            cmd_name = "demo",
            args = ArgDef[
                ArgDef(kind=AK_OPTION, name=:port, T=Int, flags=["-p", "--port"], help="Port")
            ]
        )

        txt1 = render_help(def2; 
            template=build_help_template(
                style = HELP_PLAIN,
                show_option_metavar = true
            )
        )
        @test occursin("<port>", lowercase(txt1))

        txt2 = render_help(
            def2; template=build_help_template(
                HelpTemplateOptions(
                    style = HELP_PLAIN,
                    show_option_metavar = false
                )
            )
        )
        @test occursin("-p, --port", txt2)
        @test !occursin("<port>", lowercase(txt2))
    end

    @testset "wrap description and epilog" begin
        long_desc = "This is a very long description intended to verify wrapping behavior in the help renderer."
        long_epilog = "This is a very long epilog intended to verify wrapping behavior in the help renderer."
        def2 = CliDef(
            cmd_name = "demo",
            description = long_desc,
            epilog = long_epilog
        )

        txt = render_help(def2; template=build_help_template(
            style = HELP_PLAIN,
            wrap_description = true,
            wrap_epilog = true,
            wrap_width = 40
        ))

        @test occursin("This is a very long description", txt)
        @test occursin("This is a very long epilog", txt)
        @test occursin('\n', txt)
    end

    @testset "custom titles" begin
        txt = render_help(def; template=build_help_template(
            style = HELP_PLAIN,
            title_usage = "USAGE:",
            title_positionals = "ARGS:",
            title_options = "FLAGS:",
            title_subcommands = "COMMANDS:"
        ))

        @test occursin("USAGE:", txt)
        @test occursin("ARGS:", txt)
        @test occursin("FLAGS:", txt)
        @test occursin("COMMANDS:", txt)
    end

    @testset "build_help_template returns explicit template unchanged" begin
        tpl = build_help_template(HelpTemplateOptions(style=HELP_COLORED))
        resolved = build_help_template(HelpTemplateOptions(template=tpl))
        @test resolved === tpl
    end

    @testset "build_help_template builds from overrides" begin
        tpl = build_help_template(
            HelpTemplateOptions(
                style = HELP_PLAIN,
                title_usage = "USAGE:",
                wrap_width = 88
            )
        )

        txt = render_help(def; template=tpl)
        @test occursin("USAGE:", txt)
        @test occursin("<port>::Int", txt)
    end
end

