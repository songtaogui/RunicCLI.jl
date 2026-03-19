
"""
    HelpStyle

Enumeration that controls the overall presentation mode used when building or resolving help output templates.

`HelpStyle` determines whether generated help text is rendered as plain text or with ANSI color styling.
It is primarily consumed by [`build_help_template`](@ref),
[`parse_cli`](@ref), and [`run_cli`](@ref).

This enum affects the `color_enabled` branch inside the help rendering pipeline. In practical terms,
it decides whether section titles, argument labels, item names, type markers, and other visual elements
are printed with ANSI escape sequences or emitted as unstyled text.

# Values

- [`HELP_PLAIN`](@ref)  
  Disable ANSI color output. Help text is emitted as plain, portable text suitable for terminals,
  log files, redirected output, CI environments, and any place where raw escape sequences would be undesirable.

- [`HELP_COLORED`](@ref)  
  Enable ANSI-colored output using the active [`HelpTheme`](@ref). This is typically appropriate for
  interactive terminal sessions where styled output improves readability.

# Notes

- `HelpStyle` does not itself define *which* colors are used; that is controlled by [`HelpTheme`](@ref).
- `HelpStyle` does not directly control layout, wrapping, indentation, or inline/classic item presentation;
  those are controlled by [`HelpFormatOptions`](@ref).
- If a full `help_template` is passed directly to [`parse_cli`](@ref) or [`run_cli`](@ref),
  the style resolution path is bypassed because the template is already fully constructed.
- Colored output uses ANSI escape sequences and may not display correctly in all terminals.

# Typical usage

```julia
tpl = build_help_template(style=HELP_PLAIN)
tpl = build_help_template(style=HELP_COLORED)
```

# See also

[`HELP_PLAIN`](@ref), [`HELP_COLORED`](@ref), [`build_help_template`](@ref),
[`render_help`](@ref)
"""
@enum HelpStyle begin
    HELP_PLAIN
    HELP_COLORED
end

"""
    HELP_PLAIN

A [`HelpStyle`](@ref) value that renders help text without ANSI color styling.

When `HELP_PLAIN` is used, the help rendering pipeline emits ordinary text only. This is the safest
and most broadly compatible mode, especially when help output may be:

- redirected to a file,
- captured in logs,
- compared in tests,
- displayed in environments that do not support ANSI color sequences,
- consumed by tooling that expects plain text.

# Behavior

With `HELP_PLAIN`:

- section headers are printed without terminal color escapes,
- item names and metadata are unstyled,
- label emphasis falls back to plain text unless the active label style requests bold-like formatting
  through template logic that does not depend on ANSI color,
- output remains human-readable and stable for snapshot testing.

# Common use cases

- default command help in scripts and automation,
- documentation examples,
- terminal environments with uncertain color support,
- deterministic rendering in unit tests.

# Example

```julia
tpl = build_help_template(style=HELP_PLAIN)
println(render_help(def; template=tpl))
```

# See also

[`HelpStyle`](@ref), [`HELP_COLORED`](@ref), [`default_help_template`](@ref)
"""
HELP_PLAIN

"""
    HELP_COLORED

A [`HelpStyle`](@ref) value that enables ANSI-colored help output.

When `HELP_COLORED` is used, the help renderer applies style sequences from the active [`HelpTheme`](@ref)
to usage titles, section headers, item names, status labels, types, defaults, and selected inline text.

This mode is intended for interactive terminal sessions where visual differentiation improves scanning
and readability.

# Behavior

With `HELP_COLORED`:

- usage and section titles are colorized,
- option and positional item names may be emphasized according to argument kind,
- required/default/type/count labels may be colorized depending on the configured label styles,
- reset codes are emitted after styled segments to avoid leaking formatting into subsequent output.

# Important considerations

- Output contains ANSI escape sequences. If redirected or viewed in unsupported terminals, raw control
  sequences may appear.
- The concrete colors come from [`HelpTheme`](@ref), not from `HELP_COLORED` itself.
- Layout and wrapping are still controlled independently by [`HelpFormatOptions`](@ref).

# Example

```julia
tpl = build_help_template(style=HELP_COLORED)
println(render_help(def; template=tpl))
```

# See also

[`HelpStyle`](@ref), [`HELP_PLAIN`](@ref), [`colored_help_template`](@ref), [`HelpTheme`](@ref)
"""
HELP_COLORED


"""
    HelpLabelStyle

Enumeration controlling how label-like metadata is displayed in generated help text.

`HelpLabelStyle` is used by the help formatting layer to determine the visual treatment of items such as:

- `Required`
- `Default`
- `Type: T`
- count-related metadata such as `Count of -v`

It is referenced through fields in [`HelpFormatOptions`](@ref), including:

- `required_style`
- `default_style`
- `type_style`
- `count_style`

This enum allows each metadata class to be hidden, shown plainly, emphasized in bold, or shown with color.

# Values

- `HLS_HIDDEN`  
  Do not render the label at all.

- `HLS_PLAIN`  
  Render the label as ordinary unstyled text.

- `HLS_BOLD`  
  Render the label in bold using the active theme's `bold` style when color output is enabled.
  In plain mode, this effectively degrades to plain text.

- `HLS_COLORED`  
  Render the label using the corresponding semantic color from the active [`HelpTheme`](@ref).

# Semantics

The chosen label style applies only to label-like metadata, not to full argument specifications.
For example:

- an option spec such as `-p, --port <port::Int>` is formatted separately,
- while metadata such as `(Required)` or `(Type: Int, Default: 8080)` is influenced by `HelpLabelStyle`.

# Notes

- Hiding a label does not necessarily hide the underlying value everywhere if that value is also represented
  elsewhere in the spec. For example, a metavar or inline type annotation may still appear even if the
  separate `Type:` label is hidden.
- `HLS_COLORED` only has visible effect when the resolved help template is using colored output.
- The exact text that is styled depends on the renderer path and current formatting options.

# Example

```julia
fmt = HelpFormatOptions(
    required_style = HLS_COLORED,
    default_style = HLS_PLAIN,
    type_style = HLS_HIDDEN
)
tpl = build_help_template(style=HELP_COLORED, format=fmt)
```

# See also

[`build_help_template`](@ref), [`HelpFormatOptions`](@ref)
"""
@enum HelpLabelStyle begin
    HLS_HIDDEN
    HLS_PLAIN
    HLS_BOLD
    HLS_COLORED
end

"""
    HelpTheme(; ...)

Visual theme for help rendering.

Fields:
- `reset`: ANSI reset sequence appended after styled output.
- `bold`: ANSI bold sequence used when a label/item requests bold emphasis.
- `usage_title`: Style for the usage section title.
- `section_title`: Style for section headers such as Options / Positionals / Subcommands.
- `item_name`: Style for argument specification text, such as `-f, --format`.
- `item_required`: Style for a required argument specification when emphasis-by-kind is enabled.
- `item_optional`: Style for an optional argument specification when emphasis-by-kind is enabled.
- `item_default`: Style for an argument specification that has a default value.
- `item_repeated`: Style for repeated / multi-value arguments.
- `meta`: Style for generic metadata text.
- `type_name`: Style for rendered type names.
- `required_mark`: Style for rendered `Required` labels.
- `default_mark`: Style for rendered `Default` labels.
- `inline_description`: Style for inline descriptions.
"""
Base.@kwdef struct HelpTheme
    reset::String = "\e[0m"            # reset
    bold::String = "\e[1m"             # bold

    usage_title::String = "\e[1;36m"
    section_title::String = "\e[1;33m"

    item_name::String = "\e[1;30m"
    item_required::String = "\e[1;30m"
    item_optional::String = "\e[1;30m"
    item_default::String = "\e[1;30m"
    item_repeated::String = "\e[1;35m"

    meta::String = "\e[2;37m"
    type_name::String = "\e[36m"
    required_mark::String = "\e[1;31m"
    default_mark::String = "\e[1;34m"
    inline_description::String = "\e[0m" # reset

end

# TermCode      Color            Hex
# 30            Black            #000000
# 31            Red              #800000
# 32            Green            #008000
# 33            Yellow           #808000
# 34            Blue             #000080
# 35            Magenta          #800080
# 36            Cyan             #008080
# 37            White            #C0C0C0
# 90            Bright Black     #808080
# 91            Bright Red       #FF0000
# 92            Bright Green     #00FF00
# 93            Bright Yellow    #FFFF00
# 94            Bright Blue      #0000FF
# 95            Bright Magenta   #FF00FF
# 96            Bright Cyan      #00FFFF
# 97            Bright White     #FFFFFF

"""
    HelpFormatOptions(; ...)

Formatting options for generated help text.

# Layout

- `indent_item::Int=2`  
  Number of spaces inserted before each item specification.

- `indent_text::Int=6`  
  Indentation used for wrapped text in classic multi-line layout.

- `section_gap::Bool=true`  
  Whether to insert a blank line after each non-empty section.

- `item_column_width::Int=32`  
  Width of the left specification column.

- `subcommand_col_gap::Int=2`  
  Extra spacing between subcommand name column and description column.

# Titles

- `title_usage::String="Usage:"`
- `title_positionals::String="Positional Arguments:"`
- `title_options::String="Option Arguments:"`
- `title_subcommands::String="Subcommands:"`

These control the visible section titles.

# Visibility / styling of metadata

- `required_style::HelpLabelStyle=HLS_PLAIN`  
  Controls how the `Required` marker is rendered.
  - `HLS_HIDDEN`: do not show it
  - `HLS_PLAIN`: plain text
  - `HLS_BOLD`: bold text
  - `HLS_COLORED`: use `theme.required_mark`

- `default_style::HelpLabelStyle=HLS_PLAIN`  
  Controls how default-value metadata is rendered.

- `type_style::HelpLabelStyle=HLS_PLAIN`  
  Controls how type metadata is rendered.

- `count_style::HelpLabelStyle=HLS_PLAIN`  
  Controls how count-origin metadata is rendered for count flags.

- `show_option_metavar::Bool=true`  
  Whether option specs should display a metavar placeholder.

- `show_status_labels::Bool=true`  
  Whether semantic labels like `Required` / `Default` are emitted.

# Spec rendering

- `metavar_brackets::Tuple{String,String}=("<", ">")`  
  Brackets used around option metavars.

- `emphasize_item_by_kind::Bool=true`  
  If true, argument spec color can vary by semantic kind (required/default/repeated).

# Layout mode

```text
  --flag <x::String>    Required    description
```

# Wrapping

- `wrap_description::Bool=false`  
  Whether descriptions are wrapped.

- `wrap_epilog::Bool=false`  
  Whether epilog is wrapped.

- `wrap_width::Int=0`  
  Wrapping width. If `0`, `TextWrap` default width is used unless wrapping is
  auto-enabled by `build_help_template`.

# Formatters

- `type_formatter=string`  
  Function used to turn a Julia type into display text.

- `default_formatter=repr`  
  Function used to render default values.

These let users customize displayed type names or default-value formatting.
"""
struct HelpFormatOptions{F1,F2}
    indent_item::Int
    indent_text::Int
    section_gap::Bool

    item_column_width::Int
    item_column_width_min::Int
    item_column_width_max::Int
    subcommand_col_gap::Int
    item_desc_gap::Int

    title_usage::String
    title_positionals::String
    title_options::String
    title_subcommands::String
    title_constraints::String

    required_style::HelpLabelStyle
    default_style::HelpLabelStyle
    type_style::HelpLabelStyle
    count_style::HelpLabelStyle

    show_option_metavar::Bool
    show_status_labels::Bool
    show_constraints::Bool

    metavar_brackets::Tuple{String,String}
    emphasize_item_by_kind::Bool

    wrap_description::Bool
    wrap_epilog::Bool
    wrap_width::Int

    type_formatter::F1
    default_formatter::F2
end

function HelpFormatOptions(;
    indent_item::Int = 2,
    indent_text::Int = 6,
    section_gap::Bool = true,

    item_column_width::Int = 28,
    item_column_width_min::Int = 18,
    item_column_width_max::Int = 34,
    subcommand_col_gap::Int = 2,
    item_desc_gap::Int = 2,

    title_usage::String = "Usage:",
    title_positionals::String = "Positional Arguments:",
    title_options::String = "Option Arguments:",
    title_subcommands::String = "Subcommands:",
    title_constraints::String = "Constraints:",

    required_style::HelpLabelStyle = HLS_PLAIN,
    default_style::HelpLabelStyle = HLS_PLAIN,
    type_style::HelpLabelStyle = HLS_PLAIN,
    count_style::HelpLabelStyle = HLS_PLAIN,

    show_option_metavar::Bool = true,
    show_status_labels::Bool = true,
    show_constraints::Bool = true,

    metavar_brackets::Tuple{String,String} = ("<", ">"),
    emphasize_item_by_kind::Bool = true,

    wrap_description::Bool = true,
    wrap_epilog::Bool = true,
    wrap_width::Int = 100,

    type_formatter = string,
    default_formatter = repr
)
    F1 = typeof(type_formatter)
    F2 = typeof(default_formatter)
    return HelpFormatOptions{F1,F2}(
        indent_item,
        indent_text,
        section_gap,

        item_column_width,
        item_column_width_min,
        item_column_width_max,
        subcommand_col_gap,
        item_desc_gap,

        title_usage,
        title_positionals,
        title_options,
        title_subcommands,
        title_constraints,

        required_style,
        default_style,
        type_style,
        count_style,

        show_option_metavar,
        show_status_labels,
        show_constraints,

        metavar_brackets,
        emphasize_item_by_kind,

        wrap_description,
        wrap_epilog,
        wrap_width,

        type_formatter,
        default_formatter
    )
end

"""
    HelpTemplateOptions(; ...)

Configuration object used to resolve or construct the help template applied by
[`build_help_template`](@ref), [`parse_cli`](@ref), and [`run_cli`](@ref).

`HelpTemplateOptions` centralizes all help-related customization in a single
structure. It can either:

1. pass through an already-built template via `template`, or
2. describe how a template should be built from a [`HelpStyle`](@ref),
   [`HelpTheme`](@ref), and [`HelpFormatOptions`](@ref), optionally overriding
   selected formatting fields inline.

This design allows callers to keep help configuration grouped as one value
instead of passing many separate keyword arguments.

# Resolution order

Help-template resolution follows this priority:

1. If `template !== nothing`, that template is returned directly and all other
   fields are ignored.
2. Otherwise, a new template is built from:
   - `style`
   - `theme`
   - `format`
   - any non-`nothing` override fields stored in `HelpTemplateOptions`

In other words, `format` provides the baseline formatting configuration, and the
individual optional fields in `HelpTemplateOptions` selectively override parts
of that baseline.

# Fields

## Direct template pass-through

- `template=nothing`  
  If set to a fully constructed help template, that template is used as-is.
  When this field is provided, no style/theme/format resolution is performed.

## Core help configuration

- `style::HelpStyle=HELP_PLAIN`  
  Overall presentation mode used when building a template. Controls whether help
  output is plain or ANSI-colored.

- `theme::HelpTheme=HelpTheme()`  
  Visual theme used when colored output is enabled.

- `format::HelpFormatOptions=HelpFormatOptions()`  
  Baseline formatting and metadata-display options.

## Optional per-field overrides

These fields default to `nothing`. When set, they override the corresponding
field from `format` during template construction.

### Layout

- `indent_item::Union{Nothing,Int}=nothing`  
  Override for item indentation.

- `indent_text::Union{Nothing,Int}=nothing`  
  Override for wrapped continuation indentation.

- `section_gap::Union{Nothing,Bool}=nothing`  
  Override controlling whether blank lines are inserted after sections.

- `item_column_width::Union{Nothing,Int}=nothing`  
  Override for the left specification column width.

### Titles

- `title_usage::Union{Nothing,String}=nothing`
- `title_positionals::Union{Nothing,String}=nothing`
- `title_options::Union{Nothing,String}=nothing`
- `title_subcommands::Union{Nothing,String}=nothing`
- `title_constraints::Union{Nothing,String}=nothing`

These override the visible section titles.

### Metadata label styling

- `required_style::Union{Nothing,HelpLabelStyle}=nothing`
- `default_style::Union{Nothing,HelpLabelStyle}=nothing`
- `type_style::Union{Nothing,HelpLabelStyle}=nothing`
- `count_style::Union{Nothing,HelpLabelStyle}=nothing`

These override how label-like metadata is rendered.

### Visibility toggles

- `show_option_metavar::Union{Nothing,Bool}=nothing`
- `show_status_labels::Union{Nothing,Bool}=nothing`
- `show_constraints::Union{Nothing,Bool}=nothing`

These control whether certain help elements are emitted.

### Emphasis behavior

- `emphasize_item_by_kind::Union{Nothing,Bool}=nothing`  
  Overrides whether argument specifications are visually emphasized by semantic
  kind such as required/default/repeated.

### Wrapping

- `wrap_description::Union{Nothing,Bool}=nothing`
- `wrap_epilog::Union{Nothing,Bool}=nothing`
- `wrap_width::Union{Nothing,Int}=nothing`

These override text wrapping behavior.

# Special wrapping behavior

If wrapping is enabled for descriptions or epilog text and the resolved
`wrap_width` is `0`, [`build_help_template`](@ref) promotes the width to `80`
as a fallback.

# Typical usage

Build plain help with small customizations:

```julia
help = HelpTemplateOptions(
    style = HELP_PLAIN,
    title_options = "Options:",
    wrap_width = 88
)

tpl = build_help_template(help)
```

Use colored help with a custom format baseline:

```julia
fmt = HelpFormatOptions(
    required_style = HLS_COLORED,
    default_style = HLS_PLAIN,
    wrap_width = 100
)

help = HelpTemplateOptions(
    style = HELP_COLORED,
    format = fmt
)
```

Pass a prebuilt template directly:

```julia
tpl = build_help_template(style=HELP_COLORED)
help = HelpTemplateOptions(template = tpl)
```

Use with [`parse_cli`](@ref) or [`run_cli`](@ref):

```julia
opts = parse_cli(MyCLI; help=HelpTemplateOptions(style=HELP_COLORED))

code = run_cli(help=HelpTemplateOptions(
    style = HELP_PLAIN,
    wrap_width = 90
)) do
    parse_cli(MyCLI)
end
```

# Notes

- `HelpTemplateOptions` does not itself render help text; it only describes how
  the final help template should be obtained.
- Not every field from [`HelpFormatOptions`](@ref) currently has a dedicated
  override field here. Fields without explicit overrides continue to come from
  `format`.
- If you need full control beyond these options, construct and pass a complete
  template through `template`.

# See also

[`build_help_template`](@ref), [`HelpStyle`](@ref), [`HelpTheme`](@ref),
[`HelpFormatOptions`](@ref), [`render_help`](@ref), [`parse_cli`](@ref),
[`run_cli`](@ref)
"""
Base.@kwdef struct HelpTemplateOptions
    template = nothing
    style::HelpStyle = HELP_PLAIN
    theme::HelpTheme = HelpTheme()
    format::HelpFormatOptions = HelpFormatOptions()

    indent_item::Union{Nothing,Int} = nothing
    indent_text::Union{Nothing,Int} = nothing
    section_gap::Union{Nothing,Bool} = nothing

    item_column_width::Union{Nothing,Int} = nothing

    title_usage::Union{Nothing,String} = nothing
    title_positionals::Union{Nothing,String} = nothing
    title_options::Union{Nothing,String} = nothing
    title_subcommands::Union{Nothing,String} = nothing
    title_constraints::Union{Nothing,String} = nothing

    required_style::Union{Nothing,HelpLabelStyle} = nothing
    default_style::Union{Nothing,HelpLabelStyle} = nothing
    type_style::Union{Nothing,HelpLabelStyle} = nothing
    count_style::Union{Nothing,HelpLabelStyle} = nothing

    show_option_metavar::Union{Nothing,Bool} = nothing
    show_status_labels::Union{Nothing,Bool} = nothing
    show_constraints::Union{Nothing,Bool} = nothing

    emphasize_item_by_kind::Union{Nothing,Bool} = nothing

    wrap_description::Union{Nothing,Bool} = nothing
    wrap_epilog::Union{Nothing,Bool} = nothing
    wrap_width::Union{Nothing,Int} = nothing
end

