#!/usr/bin/env julia
using Oracli

@CMD_MAIN DemoCLI begin
    @CMD_USAGE "demo [OPTIONS] [SUBCOMMAND]"
    @CMD_VERSION "0.1.2"
    @CMD_DESC "Integration test CLI for Oracli.jl"
    @CMD_EPILOG "Use --help on main or subcommands for details."
    @ARG_OPT Float64 ratio "-r" "--ratio" default=0.5 

    @CMD_SUB "run" "Run a task with positional arguments" begin
        @CMD_USAGE "demo [main-options] run [sub-options] <input> [output] [mode] [extra...]"
        @CMD_EPILOG "Example: demo -t 4 --ratio 0.5 run --format json file.txt"
        @ARG_REQ   String format   "-f" "--format" help="Required ARG for Run Looooooooooooooooooooooooooooooooooooong"
        @ARG_OPT String abcd "-a" "--abcd" help="test ENV and Default." env="MYENV" default="MyDefaultString"
        @ALLOW_EXTRA
        @POS_REQ  String input
        @POS_OPT  String output default="stdout" env="MYPOSENV"
        @POS_REST String extra
    end

    @CMD_SUB "inspect" "Simple inspector subcommand" begin
        @ARG_FLAG json "--json"
        @POS_REQ String artifact
    end

end

function print_struct_fields(x)
    T = typeof(x)
    println("== Parsed struct: ", T, " ==")
    for fn in fieldnames(T)
        v = getfield(x, fn)
        println(rpad(String(fn), 20), " => ", repr(v), " :: ", typeof(v))
    end
end

function print_namedtuple_fields(nt::NamedTuple; title::String="Subcommand payload")
    println("== ", title, " ==")
    for (k, v) in pairs(nt)
        println(rpad(String(k), 20), " => ", repr(v), " :: ", typeof(v))
    end
end

function run_demo(argv::Vector{String}=ARGS)
    try
        cfg = parse_cli(DemoCLI, argv; )
        print_struct_fields(cfg)

        if cfg.subcommand !== nothing
            println("Selected subcommand: ", cfg.subcommand)
            if cfg.subcommand_args !== nothing
                print_namedtuple_fields(cfg.subcommand_args)
            end
        end
        return cfg
    catch e
        if e isa ArgHelpRequested
            println("---- HELP ----")
            println(e.message)
            return nothing
        elseif e isa ArgParseError
            println("---- PARSE ERROR ----")
            println(e.message)
            return nothing
        else
            rethrow(e)
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_demo()
end