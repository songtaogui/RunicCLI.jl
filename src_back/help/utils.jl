
@inline _paint(io::IO, s::AbstractString, color::AbstractString, enabled::Bool, reset::AbstractString) =
    enabled ? print(io, color, s, reset) : print(io, s)

@inline _styled_text(s::AbstractString, style::AbstractString, enabled::Bool, reset::AbstractString) =
    enabled ? string(style, s, reset) : String(s)

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


function _wrap_inline_text_lines(txt::AbstractString, width::Int)
    io = IOBuffer()
    if width > 0
        println_wrapped(io, txt, initial_indent=0, subsequent_indent=0, width=width)
    else
        println(io, txt)
    end
    s = String(take!(io))
    lines = split(chomp(s), '\n')
    isempty(lines) && return [""]
    return lines
end
