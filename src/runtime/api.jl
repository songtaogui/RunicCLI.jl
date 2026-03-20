function parse_cli(
    ::Type{T},
    args::Vector{String}=ARGS;
    allow_empty_option_value::Bool=false,
    help::HelpTemplateOptions=HelpTemplateOptions(),
    env_prefix::String="",
    env::AbstractDict=ENV,
    config::AbstractDict=Dict{String,Any}(),
    config_file::Union{Nothing,String}=nothing
) where {T}
    if !(hasfield(T, :subcommand) && hasfield(T, :subcommand_args))
        throw(ArgumentError("parse_cli expects a @CMD_MAIN generated type"))
    end

    local resolved_template = build_help_template(help)

    try
        return T(
            args;
            allow_empty_option_value=allow_empty_option_value,
            env_prefix=env_prefix,
            env=env,
            config=config,
            config_file=config_file
        )
    catch e
        if e isa ArgHelpRequested
            throw(ArgHelpRequested(e.def, e.path, isempty(e.message) ? render_help(e.def; template=resolved_template, path=e.path) : e.message))
        else
            rethrow()
        end
    end
end


function run_cli(
    f::Function;
    io::IO=stdout,
    err_io::IO=stderr,
    debug::Bool=false,
    on_error::Function = (e)->nothing,
    help::HelpTemplateOptions=HelpTemplateOptions()
)::Int
    local resolved_template = build_help_template(help)

    try
        f()
        return 0
    catch e
        if e isa ArgHelpRequested
            local msg = if !isempty(e.message)
                e.message
            else
                render_help(e.def; template=resolved_template, path=e.path)
            end
            if !isempty(msg)
                print(io, msg)
                endswith(msg, '\n') || println(io)
            end
            return 0
        elseif e isa ArgParseError
            println(err_io, sprint(showerror, e))
            on_error(e)
            if debug
                println(err_io, "---- debug backtrace ----")
                Base.showerror(err_io, e, catch_backtrace())
                println(err_io)
                println(err_io, "-------------------------")
            end
            return 2
        else
            on_error(e)
            rethrow()
        end
    end
end
