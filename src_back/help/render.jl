
"""
    render_help(def::CliDef; template::ArgHelpTemplate=default_help_template(), path::String="") -> String

Render a complete help message for a CLI definition into a string.

`render_help` is the high-level formatter that takes a [`CliDef`](@ref), applies
an [`ArgHelpTemplate`](@ref), and returns the final help text as a `String`.

This function does not print directly. It is used internally by RunicCLI when
servicing help requests, and it can also be used manually for documentation
generation, testing, or custom UI flows.

# Parameters

- `def::CliDef`  
  The command definition to render.

- `template::ArgHelpTemplate=default_help_template()`  
  The fully resolved template used to render help.

- `path::String=""`  
  Command path used for usage fallback generation and subcommand-aware help,
  such as `"mycli serve"`.

# Return value

Returns a single `String` containing the complete rendered help output.

# Notes

- `render_help` formats only; it does not print.
- To control how the template itself is built, see
  [`HelpTemplateOptions`](@ref) and [`build_help_template`](@ref).
- Higher-level APIs such as [`parse_cli`](@ref) and [`run_cli`](@ref) can
  resolve `HelpTemplateOptions` for you.

# Example

```julia
txt = render_help(def)
println(txt)
```

With a custom template:

```julia
tpl = build_help_template(style=HELP_COLORED)
txt = render_help(def; template=tpl, path="mycli serve")
```

# See also

[`build_help_template`](@ref), [`HelpTemplateOptions`](@ref),
[`default_help_template`](@ref), [`colored_help_template`](@ref),
[`CliDef`](@ref), [`ArgHelpTemplate`](@ref)
"""
function render_help(def::CliDef; template::ArgHelpTemplate=default_help_template(), path::String="")
    io = IOBuffer()

    _call_and_capture = function (f)
        tmp = IOBuffer()
        f(tmp, def, path)
        return String(take!(tmp))
    end

    sections = (
        template.header,
        template.section_usage,
        template.section_description,
        template.section_positionals,
        template.section_options,
        template.section_subcommands,
        template.section_epilog
    )

    for sec in sections
        s = _call_and_capture(sec)
        isempty(s) && continue
        print(io, s)
    end

    return String(take!(io))
end