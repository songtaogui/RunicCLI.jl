# RunicCLI
# help.jl

@enum HelpStyle begin
    HELP_PLAIN
    HELP_COLORED
end

Base.@kwdef struct HelpTheme
    reset::String = "\e[0m"
    usage_title::String = "\e[1;36m"
    section_title::String = "\e[1;33m"
    item_name::String = "\e[1;32m"
    meta::String = "\e[2;37m"
end

struct HelpFormatOptions{F1,F2}
    indent_item::Int
    indent_text::Int
    section_gap::Bool
    title_usage::String
    title_positionals::String
    title_options::String
    title_subcommands::String
    show_type::Bool
    show_required::Bool
    show_default::Bool
    show_count_origin::Bool
    show_option_metavar::Bool
    metavar_brackets::Tuple{String,String}
    wrap_description::Bool
    wrap_epilog::Bool
    wrap_width::Int
    subcommand_col_gap::Int
    type_formatter::F1
    default_formatter::F2
end

function HelpFormatOptions(;
    indent_item::Int = 2,
    indent_text::Int = 6,
    section_gap::Bool = true,
    title_usage::String = "Usage:",
    title_positionals::String = "Positional Arguments:",
    title_options::String = "Option Arguments:",
    title_subcommands::String = "Subcommands:",
    show_type::Bool = true,
    show_required::Bool = true,
    show_default::Bool = true,
    show_count_origin::Bool = true,
    show_option_metavar::Bool = true,
    metavar_brackets::Tuple{String,String} = ("<", ">"),
    wrap_description::Bool = false,
    wrap_epilog::Bool = false,
    wrap_width::Int = 0,
    subcommand_col_gap::Int = 2,
    type_formatter = string,
    default_formatter = repr
)
    F1 = typeof(type_formatter)
    F2 = typeof(default_formatter)
    return HelpFormatOptions{F1,F2}(
        indent_item, indent_text, section_gap,
        title_usage, title_positionals, title_options, title_subcommands,
        show_type, show_required, show_default, show_count_origin, show_option_metavar,
        metavar_brackets, wrap_description, wrap_epilog, wrap_width,
        subcommand_col_gap, type_formatter, default_formatter
    )
end

@inline _paint(io::IO, s::AbstractString, color::AbstractString, enabled::Bool, reset::AbstractString) =
    enabled ? print(io, color, s, reset) : print(io, s)

@inline function _print_wrapped(io::IO, txt::AbstractString; initial_indent::Int=0, subsequent_indent::Int=0, width::Int=0)
    if width > 0
        println_wrapped(io, txt, initial_indent=initial_indent, subsequent_indent=subsequent_indent, width=width)
    else
        println_wrapped(io, txt, initial_indent=initial_indent, subsequent_indent=subsequent_indent)
    end
end

@inline function _rpad_display(s::AbstractString, target_width::Int)
    w = textwidth(s)
    w >= target_width && return String(s)
    return String(s) * " "^(target_width - w)
end


function _help_usage_fallback(def::CliDef, path::String)
    cmd = isempty(path) ? def.cmd_name : path
    parts = String[cmd]

    has_opts = any(a -> a.kind in (AK_FLAG, AK_COUNT, AK_OPTION, AK_OPTION_MULTI), def.args)
    has_pos = any(a -> a.kind in (AK_POS_REQUIRED, AK_POS_DEFAULT, AK_POS_OPTIONAL, AK_POS_REST), def.args)
    has_sub = !isempty(def.subcommands)

    has_opts && push!(parts, "[OPTIONS]")
    has_sub && push!(parts, "[SUBCOMMAND]")
    has_pos && push!(parts, "[ARGS...]")

    return join(parts, " ")
end


function _format_positional_spec(a::ArgDef, opts::HelpFormatOptions)
    n = isempty(a.help_name) ? String(a.name) : a.help_name
    if a.kind == AK_POS_REQUIRED
        return n
    elseif a.kind == AK_POS_DEFAULT
        if opts.show_default
            return "[$n=$(opts.default_formatter(a.default))]"
        else
            return "[$n]"
        end
    elseif a.kind == AK_POS_OPTIONAL
        return "[$n]"
    else
        return "[$n...]"
    end
end

function _format_option_spec(a::ArgDef, opts::HelpFormatOptions)
    names = join(a.flags, ", ")
    if !opts.show_option_metavar
        return names
    end
    if a.kind in (AK_OPTION, AK_OPTION_MULTI)
        name = isempty(a.help_name) ? String(a.name) : a.help_name
        l, r = opts.metavar_brackets
        return string(names, " ", l, name, r)
    end
    return names
end

function _format_meta_line(a::ArgDef, opts::HelpFormatOptions)
    parts = String[]
    if opts.show_type
        if a.kind == AK_FLAG
            push!(parts, "Type: Bool")
        elseif a.kind == AK_COUNT
            if opts.show_count_origin
                push!(parts, "Type: Int, count of $(a.flags[1])")
            else
                push!(parts, "Type: Int")
            end
        elseif a.kind == AK_OPTION_MULTI
            push!(parts, "Type: Vector{$(opts.type_formatter(a.T))}")
        else
            push!(parts, "Type: $(opts.type_formatter(a.T))")
        end
    end

    if opts.show_required && a.kind == AK_OPTION && a.required
        push!(parts, "Required")
    end

    if opts.show_default && ((a.kind == AK_OPTION && !a.required) || a.kind == AK_POS_DEFAULT)
        push!(parts, "Default: $(opts.default_formatter(a.default))")
    end

    isempty(parts) && return ""
    return "(" * join(parts, ", ") * ")"
end

"""
    build_help_template(; kwargs...) -> ArgHelpTemplate

Build a configurable help template.

This function is the primary customization entrypoint for help rendering.
It unifies plain and ANSI-colored output under one parameterized template factory.

# Core style selection
- `style::HelpStyle=HELP_PLAIN`: choose plain or colored mode.
- `theme::HelpTheme=HelpTheme()`: color codes used when `style=HELP_COLORED`.

# Layout and content options
- `format::HelpFormatOptions=HelpFormatOptions()`: full formatting policy.
- `indent_item::Int`, `indent_text::Int`, `section_gap::Bool`: override selected layout fields.
- `show_type`, `show_default`, `show_required`, `show_option_metavar`: quick toggles.

# Section title overrides
- `title_usage`, `title_positionals`, `title_options`, `title_subcommands`

# Wrapping behavior
- `wrap_description::Bool`: wrap command description using `TextWrap.println_wrapped`.
- `wrap_epilog::Bool`: wrap epilog text.

# Usage fallback behavior
When `CliDef.usage` is empty, fallback usage is computed dynamically from schema:
- include `[OPTIONS]` only if options exist
- include `[ARGS]` only if positional args exist
- include `[SUBCOMMAND]` only if subcommands exist

This avoids misleading fixed usage tails for commands that do not support
certain sections.

# Return
An `ArgHelpTemplate` object consumable by `render_help`.

# Example
```julia
tpl = build_help_template(
    style = HELP_COLORED,
    indent_item = 4,
    show_option_metavar = true,
    wrap_description = true
)

println(render_help(cli_def; template=tpl))
```
"""
function build_help_template(;
    style::HelpStyle = HELP_PLAIN,
    theme::HelpTheme = HelpTheme(),
    format::HelpFormatOptions = HelpFormatOptions(),
    indent_item::Union{Nothing,Int}=nothing,
    indent_text::Union{Nothing,Int}=nothing,
    section_gap::Union{Nothing,Bool}=nothing,
    show_type::Union{Nothing,Bool}=nothing,
    show_default::Union{Nothing,Bool}=nothing,
    show_required::Union{Nothing,Bool}=nothing,
    show_option_metavar::Union{Nothing,Bool}=nothing,
    title_usage::Union{Nothing,String}=nothing,
    title_positionals::Union{Nothing,String}=nothing,
    title_options::Union{Nothing,String}=nothing,
    title_subcommands::Union{Nothing,String}=nothing,
    wrap_description::Union{Nothing,Bool}=nothing,
    wrap_epilog::Union{Nothing,Bool}=nothing,
    wrap_width::Union{Nothing,Int}=nothing
)
    wd = isnothing(wrap_description) ? format.wrap_description : wrap_description
    we = isnothing(wrap_epilog) ? format.wrap_epilog : wrap_epilog
    ww = isnothing(wrap_width) ? format.wrap_width : wrap_width
    if ww == 0 && (wd || we)
        ww = 80
    end

    opts = HelpFormatOptions(
        indent_item = isnothing(indent_item) ? format.indent_item : indent_item,
        indent_text = isnothing(indent_text) ? format.indent_text : indent_text,
        section_gap = isnothing(section_gap) ? format.section_gap : section_gap,
        title_usage = isnothing(title_usage) ? format.title_usage : title_usage,
        title_positionals = isnothing(title_positionals) ? format.title_positionals : title_positionals,
        title_options = isnothing(title_options) ? format.title_options : title_options,
        title_subcommands = isnothing(title_subcommands) ? format.title_subcommands : title_subcommands,
        show_type = isnothing(show_type) ? format.show_type : show_type,
        show_required = isnothing(show_required) ? format.show_required : show_required,
        show_default = isnothing(show_default) ? format.show_default : show_default,
        show_count_origin = format.show_count_origin,
        show_option_metavar = isnothing(show_option_metavar) ? format.show_option_metavar : show_option_metavar,
        metavar_brackets = format.metavar_brackets,
        wrap_description = wd,
        wrap_epilog = we,
        wrap_width = ww,
        subcommand_col_gap = format.subcommand_col_gap,
        type_formatter = format.type_formatter,
        default_formatter = format.default_formatter
    )

    color_enabled = style == HELP_COLORED

    return ArgHelpTemplate(
        header = (io, def, path)->begin
            _paint(io, opts.title_usage, theme.usage_title, color_enabled, theme.reset)
            print(io, " ")
            if !isempty(def.usage)
                println(io, def.usage)
            else
                println(io, _help_usage_fallback(def, path))
            end
            opts.section_gap && println(io)
        end,
        section_usage = (io, def, path)->nothing,
        section_description = (io, def, path)->begin
            isempty(def.description) && return
            if opts.wrap_description
                _print_wrapped(io, def.description, initial_indent=0, subsequent_indent=0, width=opts.wrap_width)
            else
                println(io, def.description)
            end
            opts.section_gap && println(io)
        end,
        section_positionals = (io, def, path)->begin
            pos = filter(a -> a.kind in (AK_POS_REQUIRED, AK_POS_DEFAULT, AK_POS_OPTIONAL, AK_POS_REST), def.args)
            isempty(pos) && return
            _paint(io, opts.title_positionals, theme.section_title, color_enabled, theme.reset)
            println(io)
            for a in pos
                spec = _format_positional_spec(a, opts)
                print(io, " "^opts.indent_item)
                _paint(io, spec, theme.item_name, color_enabled, theme.reset)
                println(io)
                if !isempty(a.help)
                    _print_wrapped(io, a.help, initial_indent=opts.indent_text, subsequent_indent=opts.indent_text, width=opts.wrap_width)
                end
                meta = _format_meta_line(a, opts)
                if !isempty(meta)
                    print(io, " "^opts.indent_text)
                    _paint(io, meta, theme.meta, color_enabled, theme.reset)
                    println(io)
                end
            end
            opts.section_gap && println(io)
        end,
        section_options = (io, def, path)->begin
            opt = filter(a -> a.kind in (AK_FLAG, AK_COUNT, AK_OPTION, AK_OPTION_MULTI), def.args)
            isempty(opt) && return
            _paint(io, opts.title_options, theme.section_title, color_enabled, theme.reset)
            println(io)
            for a in opt
                spec = _format_option_spec(a, opts)
                print(io, " "^opts.indent_item)
                _paint(io, spec, theme.item_name, color_enabled, theme.reset)
                println(io)
                if !isempty(a.help)
                    _print_wrapped(io, a.help, initial_indent=opts.indent_text, subsequent_indent=opts.indent_text, width=opts.wrap_width)
                end
                meta = _format_meta_line(a, opts)
                if !isempty(meta)
                    print(io, " "^opts.indent_text)
                    _paint(io, meta, theme.meta, color_enabled, theme.reset)
                    println(io)
                end
            end
            opts.section_gap && println(io)
        end,
        section_subcommands = (io, def, path)->begin
            isempty(def.subcommands) && return
            _paint(io, opts.title_subcommands, theme.section_title, color_enabled, theme.reset)
            println(io)
            w = maximum(textwidth(s.name) for s in def.subcommands)
            for s in def.subcommands
                print(io, " "^opts.indent_item)
                name_cell = _rpad_display(s.name, w + opts.subcommand_col_gap)
                _paint(io, name_cell, theme.item_name, color_enabled, theme.reset)
                println(io, s.description)
            end
            opts.section_gap && println(io)
        end,
        section_epilog = (io, def, path)->begin
            isempty(def.epilog) && return
            if opts.wrap_epilog
                _print_wrapped(io, def.epilog, initial_indent=0, subsequent_indent=0, width=opts.wrap_width)
            else
                println(io, def.epilog)
            end
            opts.section_gap && println(io)
        end
    )
end

"""
`default_help_template() -> ArgHelpTemplate`

Build the default plain-text help template.

Equivalent to:
`build_help_template(style=HELP_PLAIN)`
"""
default_help_template() = build_help_template(style=HELP_PLAIN)

"""
`colored_help_template() -> ArgHelpTemplate`

Build the default ANSI-colored help template.

Equivalent to:
`build_help_template(style=HELP_COLORED)`
"""
colored_help_template() = build_help_template(style=HELP_COLORED)

"""
`render_help(def::CliDef; template::ArgHelpTemplate=default_help_template(), path::String="") -> String`

Render a complete help message from a command definition.

# Arguments
- `def`: command schema to render.
- `template`: section renderer callbacks.
- `path`: command path override used in usage/header formatting.

# Returns
A fully formatted help string ready to print.
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

