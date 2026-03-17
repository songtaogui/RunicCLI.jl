# RunicCLI
# errors.jl

Base.showerror(io::IO, e::ArgParseError) = print(io, "Argument parsing error: ", e.message)
Base.showerror(io::IO, e::ArgHelpRequested) = print(io, e.message)

@inline function _throw_arg_error(msg::String)
    throw(ArgParseError(msg))
end

"""
    run_cli(f::Function; io::IO=stdout, err_io::IO=stderr) -> Int

Execute a CLI entry function and normalize control-flow exceptions into process-like exit codes.

Conventions:
- Returns `0` on success.
- Returns `0` on `ArgHelpRequested` (help is not an error), printed to `io`.
- Returns `2` on `ArgParseError`, printed to `err_io`.
- Re-throws any other exception.
"""
function run_cli(
    f::Function;
    io::IO=stdout,
    err_io::IO=stderr,
    debug::Bool=false,
    on_error::Function = (e)->nothing
)::Int
    try
        f()
        return 0
    catch e
        if e isa ArgHelpRequested
            msg = e.message
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


@inline function _throw_arg_error_ctx(name::AbstractString, expected::AbstractString, got; hint::AbstractString="")
    g = repr(got)
    msg = "Invalid value for $(name): expected $(expected), got $(g)"
    if !isempty(hint)
        msg *= ". " * String(hint)
    end
    throw(ArgParseError(msg))
end
