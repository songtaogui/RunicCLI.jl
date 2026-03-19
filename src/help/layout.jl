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

function _type_text(a::ArgDef, opts::HelpFormatOptions)
    if a.kind == AK_FLAG
        return "Bool"
    elseif a.kind == AK_COUNT
        return "Int"
    elseif a.kind == AK_OPTION_MULTI
        return "Vector{$(opts.type_formatter(a.T))}"
    else
        return string(opts.type_formatter(a.T))
    end
end

function _render_inline_type_suffix(a::ArgDef, opts::HelpFormatOptions, theme::HelpTheme, color_enabled::Bool)
    opts.type_style == HLS_HIDDEN && return ""

    txt = "::" * _type_text(a, opts)

    if opts.type_style == HLS_PLAIN
        return txt
    elseif opts.type_style == HLS_BOLD
        return _styled_text(txt, theme.bold, color_enabled, theme.reset)
    elseif opts.type_style == HLS_COLORED
        return _styled_text(txt, theme.type_name, color_enabled, theme.reset)
    else
        return txt
    end
end

function _item_style_for_arg(a::ArgDef, theme::HelpTheme, opts::HelpFormatOptions)
    if !opts.emphasize_item_by_kind
        return theme.item_name
    end
    if a.kind == AK_OPTION && a.required
        return theme.item_required
    elseif a.kind == AK_POS_REQUIRED
        return theme.item_required
    elseif a.kind == AK_POS_DEFAULT || (a.kind == AK_OPTION && !a.required && a.default !== nothing)
        return theme.item_default
    elseif a.kind == AK_OPTION_MULTI || a.kind == AK_POS_REST
        return theme.item_repeated
    else
        return theme.item_optional
    end
end

function _label_render(text::String, style::HelpLabelStyle, color::String, theme::HelpTheme, color_enabled::Bool)
    if style == HLS_HIDDEN
        return ""
    elseif style == HLS_PLAIN
        return text
    elseif style == HLS_BOLD
        return _styled_text(text, theme.bold, color_enabled, theme.reset)
    else
        return _styled_text(text, color, color_enabled, theme.reset)
    end
end

function _format_positional_spec(a::ArgDef, opts::HelpFormatOptions, theme::HelpTheme, color_enabled::Bool)
    n = isempty(a.help_name) ? String(a.name) : a.help_name
    ts = _render_inline_type_suffix(a, opts, theme, color_enabled)
    base_name = n * ts

    if a.kind == AK_POS_REQUIRED
        return base_name
    elseif a.kind == AK_POS_DEFAULT
        return "[$base_name]"
    elseif a.kind == AK_POS_OPTIONAL
        return "[$base_name]"
    else
        return "[" * n * "..." * ts * "]"
    end
end

function _format_option_spec(a::ArgDef, opts::HelpFormatOptions, theme::HelpTheme, color_enabled::Bool)
    names = join(a.flags, ", ")
    ts = _render_inline_type_suffix(a, opts, theme, color_enabled)

    if !opts.show_option_metavar
        return names * ts
    end

    if a.kind in (AK_OPTION, AK_OPTION_MULTI)
        name = isempty(a.help_name) ? String(a.name) : a.help_name
        l, r = opts.metavar_brackets
        return string(names, " ", l, name, r, ts)
    end

    return names * ts
end

function _status_parts(a::ArgDef, opts::HelpFormatOptions, theme::HelpTheme, color_enabled::Bool)
    parts = String[]

    if opts.show_status_labels
        if (a.kind == AK_OPTION && a.required) || a.kind == AK_POS_REQUIRED
            lbl = _label_render("Required", opts.required_style, theme.required_mark, theme, color_enabled)
            isempty(lbl) || push!(parts, lbl)
        elseif (a.kind == AK_OPTION && !a.required && a.default !== nothing) || a.kind == AK_POS_DEFAULT
            lbl = _label_render("Default", opts.default_style, theme.default_mark, theme, color_enabled)
            isempty(lbl) || push!(parts, lbl)
        end
    end

    return parts
end

function _meta_parts(a::ArgDef, opts::HelpFormatOptions, theme::HelpTheme, color_enabled::Bool)
    parts = String[]

    append!(parts, _status_parts(a, opts, theme, color_enabled))

    if a.kind == AK_COUNT && opts.count_style != HLS_HIDDEN
        ctxt = _label_render("Count of " * a.flags[1], opts.count_style, theme.meta, theme, color_enabled)
        isempty(ctxt) || push!(parts, ctxt)
    end

    if opts.default_style != HLS_HIDDEN && ((a.kind == AK_OPTION && !a.required && a.default !== nothing) || a.kind == AK_POS_DEFAULT)
        dtxt = _label_render("Default: " * String(opts.default_formatter(a.default)), opts.default_style, theme.default_mark, theme, color_enabled)
        isempty(dtxt) || push!(parts, dtxt)
    end

    return parts
end

function _build_inline_description(a::ArgDef, opts::HelpFormatOptions, theme::HelpTheme, color_enabled::Bool)
    segs = String[]

    meta = _meta_parts(a, opts, theme, color_enabled)
    if !isempty(meta)
        push!(segs, join(meta, ". ") * ".")
    end

    if !isempty(a.help)
        push!(segs, a.help)
    end

    return join(segs, " ")
end

function _compute_item_column_width(args::Vector{ArgDef}, specs::Vector{String}, opts::HelpFormatOptions)
    isempty(specs) && return opts.item_column_width

    w = maximum(textwidth(s) for s in specs)
    w = max(w, opts.item_column_width_min)
    w = min(w, opts.item_column_width_max)
    return w
end

function _render_item_inline(io::IO, a::ArgDef, spec::String, spec_width::Int, opts::HelpFormatOptions, theme::HelpTheme, color_enabled::Bool)
    left_pad = " "^opts.indent_item
    desc = _build_inline_description(a, opts, theme, color_enabled)

    spec_cell = _rpad_display(spec, spec_width)
    gap = " "^opts.item_desc_gap

    desc_width = opts.wrap_width > 0 ? max(10, opts.wrap_width - opts.indent_item - spec_width - opts.item_desc_gap) : 0
    desc_lines = isempty(desc) ? String[""] : _wrap_inline_text_lines(desc, desc_width)

    print(io, left_pad)
    _paint(io, spec_cell, _item_style_for_arg(a, theme, opts), color_enabled, theme.reset)

    if !isempty(desc_lines[1])
        print(io, gap)
        _paint(io, desc_lines[1], theme.inline_description, color_enabled, theme.reset)
    end
    println(io)

    if length(desc_lines) > 1
        cont_prefix = left_pad * " "^spec_width * gap
        for i in 2:length(desc_lines)
            print(io, cont_prefix)
            _paint(io, desc_lines[i], theme.inline_description, color_enabled, theme.reset)
            println(io)
        end
    end
end