

"""
    @CMD_MAIN TypeName begin
        ...
    end

Define a full command-line interface (CLI) schema and generate a concrete parser-backed type.

`@CMD_MAIN` is the entry macro of RunicCLI's DSL. It compiles a declarative command specification
into:

1. A concrete `struct TypeName` for parsed results.
2. A constructor `TypeName(argv::Vector{String}=ARGS; allow_empty_option_value=false)` that parses arguments.
3. Compatibility with `parse_cli(TypeName, argv)` and `run_cli(...)`.
4. Built-in help handling via `-h/--help`, including subcommand help.

The generated type always includes two extra fields:

- `subcommand::Union{Nothing,String}`
- `subcommand_args::Union{Nothing,NamedTuple}`

When no subcommand is selected, both are `nothing`.

---

## Allowed content inside `@CMD_MAIN`

Only DSL macros are allowed in the block (non-macro statements are rejected).

### Command metadata
- `@CMD_USAGE "..."` — custom usage line.
- `@CMD_DESC "..."` — command description.
- `@CMD_EPILOG "..."` — trailing help text.
- `@ALLOW_EXTRA` — allow unknown/unconsumed trailing arguments.

### Option arguments
- `@ARG_REQ T name flags... [help="..."] [help_name="..."]`
- `@ARG_DEF T default name flags... [help="..."] [help_name="..."]`
- `@ARG_OPT T name flags... [help="..."] [help_name="..."]`
- `@ARG_FLAG name flags... [help="..."] [help_name="..."]`
- `@ARG_COUNT name flags... [help="..."] [help_name="..."]`
- `@ARG_MULTI T name flags... [help="..."] [help_name="..."]`

### Positional arguments
- `@POS_REQ T name [help="..."] [help_name="..."]`
- `@POS_DEF T default name [help="..."] [help_name="..."]`
- `@POS_OPT T name [help="..."] [help_name="..."]`
- `@POS_REST T name [help="..."] [help_name="..."]` (must be last; only one allowed)

### Validation and constraints
- `@ARG_TEST name fn [msg]` — post-parse validator (`nothing` is skipped).
- `@ARG_STREAM name fn [msg]` — vector element-wise validation, scalar fallback.
- `@GROUP_EXCL a b c ...` — mutual exclusion by explicit presence (option-style args only).

### Subcommands
- `@CMD_SUB "name" begin ... end`
- `@CMD_SUB "name" "description" begin ... end`

Each subcommand supports the same DSL subset (metadata, args, validators, exclusivity, `@ALLOW_EXTRA`).

---

## Parsing behavior summary

- Short bundles are supported (e.g. `-abc`) for letter flags.
- `--` stops option parsing; remaining tokens are positional.
- Required options/positionals are enforced.
- Typed conversion is applied (`parse` / `tryparse` / constructor fallback).
- Duplicate option names and duplicate flag aliases are compile-time errors.
- Unknown leftover arguments: rejected by default, accepted when `@ALLOW_EXTRA` is present.
- For negative positional numbers, users may need `--` to disambiguate from options.

---

## Help behavior

- `-h` / `--help` before `--` triggers help output via `ArgHelpRequested`.
- Main command help includes subcommand list.
- `cmd sub --help` renders subcommand-specific help.
- If `@CMD_USAGE` is omitted, usage is auto-generated from declared args/subcommands.
- Help text comes from `help="..."` and `help_name="..."` metadata.

---

## Result shape

For declared fields, the generated struct uses these types:

- `@ARG_REQ T` / `@ARG_DEF T` / `@POS_REQ T` / `@POS_DEF T` => `T`
- `@ARG_OPT T` / `@POS_OPT T` => `Union{T,Nothing}`
- `@ARG_FLAG` => `Bool`
- `@ARG_COUNT` => `Int`
- `@ARG_MULTI T` / `@POS_REST T` => `Vector{T}`

Subcommand payload is a `NamedTuple` in `subcommand_args`.

---

## Example

```julia
@CMD_MAIN MyCLI begin
    @CMD_DESC "Example CLI built with RunicCLI"
    @CMD_USAGE "mycli [OPTIONS] [SUBCOMMAND] [ARGS...]"
    @CMD_EPILOG "Tip: use '--' before negative positional numbers."

    @ARG_FLAG verbose "-v" "--verbose" help="Enable verbose logging"
    @ARG_DEF Int 8080 port "-p" "--port" help="Server port"
    @ARG_OPT String config "--config" help="Optional config path"
    @ARG_MULTI String tag "-t" "--tag" help="Repeatable tag"
    @ARG_COUNT quiet "-q" "--quiet" help="Reduce output (repeatable)"

    @POS_REQ String input help="Input file"
    @POS_OPT String mode help="Run mode"
    @POS_REST String extras help="Additional positional arguments"

    @ARG_TEST port x -> x > 0 "Port must be positive"
    @ARG_STREAM tag x -> !isempty(x) "Tags must be non-empty"

    @GROUP_EXCL verbose quiet

    @CMD_SUB "serve" "Run server" begin
        @ARG_FLAG daemon "-d" "--daemon" help="Run in background"
        @ARG_REQ String host "--host" help="Bind host"
    end
end
```

Use with:

```julia
opts = parse_cli(MyCLI, ["--port", "9000", "input.txt"])
code = run_cli() do
    o = parse_cli(MyCLI)
    # application logic
end
```

---

## Notes

- `TypeName` must be a plain symbol (not a dotted path).
- `@CMD_MAIN` is the only top-level DSL entry for generating a parseable command type.
- Placeholder macro calls outside `@CMD_MAIN`/`@CMD_SUB` are invalid.
"""
macro CMD_MAIN(struct_name, block)
    if !(block isa Expr && block.head == :block)
        throw(ArgumentError("@CMD_MAIN expects a `begin ... end` block as second argument"))
    end

    # Only allow plain type name symbols to avoid invalid `struct A.B` generation
    if !(struct_name isa Symbol)
        throw(ArgumentError("@CMD_MAIN first argument must be a plain type name Symbol (e.g. MyType), dotted names are not supported"))
    end

    nonmacro = _nonmacro_nodes(block)
    if !isempty(nonmacro)
        throw(ArgumentError("Only DSL macros are allowed inside @CMD_MAIN block; found non-macro statement(s)"))
    end

    usage = ""
    desc = ""
    epilog = ""
    allow_extra = false

    seen_usage = false
    seen_desc = false
    seen_epilog = false
    seen_allow = false

    main_nodes = Expr[]
    normalized_sub_nodes = NormalizedSubCmd[]

    for node in _getmacrocalls(block)
        m = _getmacroname(node)

        if m == SYM_USAGE
            seen_usage && throw(ArgumentError("@CMD_USAGE is duplicated in @CMD_MAIN"))
            length(node.args) >= 3 || throw(ArgumentError("@CMD_USAGE expects one String literal"))
            node.args[3] isa String || throw(ArgumentError("@CMD_USAGE expects a String literal"))
            usage = node.args[3]
            seen_usage = true

        elseif m == SYM_DESC
            seen_desc && throw(ArgumentError("@CMD_DESC is duplicated in @CMD_MAIN"))
            length(node.args) >= 3 || throw(ArgumentError("@CMD_DESC expects one String literal"))
            node.args[3] isa String || throw(ArgumentError("@CMD_DESC expects a String literal"))
            desc = node.args[3]
            seen_desc = true

        elseif m == SYM_EPILOG
            seen_epilog && throw(ArgumentError("@CMD_EPILOG is duplicated in @CMD_MAIN"))
            length(node.args) >= 3 || throw(ArgumentError("@CMD_EPILOG expects one String literal"))
            node.args[3] isa String || throw(ArgumentError("@CMD_EPILOG expects a String literal"))
            epilog = node.args[3]
            seen_epilog = true

        elseif m == SYM_ALLOW
            seen_allow && throw(ArgumentError("@ALLOW_EXTRA is duplicated in @CMD_MAIN"))
            allow_extra = true
            seen_allow = true

        elseif m == SYM_SUB
            length(node.args) >= 4 || throw(ArgumentError("@CMD_SUB expects \"name\" begin ... end or \"name\" \"desc\" begin ... end"))

            sub_name = node.args[3]
            sub_name isa String || throw(ArgumentError("@CMD_SUB name must be a String literal"))
            startswith(sub_name, "-") && throw(ArgumentError("@CMD_SUB name must not start with '-'"))

            sub_desc = ""
            sub_usage = ""
            sub_epilog = ""
            sub_allow_extra = false
            sub_block = nothing

            if length(node.args) == 4
                sub_block = node.args[4]
            elseif length(node.args) == 5
                if node.args[4] isa String
                    sub_desc = node.args[4]
                    sub_block = node.args[5]
                else
                    throw(ArgumentError("@CMD_SUB second argument must be a String description when 5 arguments are used"))
                end
            else
                throw(ArgumentError("@CMD_SUB expects \"name\" begin ... end or \"name\" \"desc\" begin ... end"))
            end

            (sub_block isa Expr && sub_block.head == :block) || throw(ArgumentError("@CMD_SUB body must be a begin...end block"))

            nonmacro_sub = _nonmacro_nodes(sub_block)
            if !isempty(nonmacro_sub)
                throw(ArgumentError("Only DSL macros are allowed inside @CMD_SUB block; found non-macro statement(s)"))
            end

            seen_sub_desc = !isempty(sub_desc)
            seen_sub_usage = false
            seen_sub_epilog = false
            seen_sub_allow = false

            for n in _getmacrocalls(sub_block)
                mm = _getmacroname(n)
                if mm == SYM_DESC
                    seen_sub_desc && throw(ArgumentError("@CMD_DESC is duplicated in @CMD_SUB \"$sub_name\""))
                    length(n.args) >= 3 || throw(ArgumentError("@CMD_DESC in @CMD_SUB expects one String literal"))
                    n.args[3] isa String || throw(ArgumentError("@CMD_DESC in @CMD_SUB expects a String literal"))
                    sub_desc = n.args[3]
                    seen_sub_desc = true

                elseif mm == SYM_USAGE
                    seen_sub_usage && throw(ArgumentError("@CMD_USAGE is duplicated in @CMD_SUB \"$sub_name\""))
                    length(n.args) >= 3 || throw(ArgumentError("@CMD_USAGE in @CMD_SUB expects one String literal"))
                    n.args[3] isa String || throw(ArgumentError("@CMD_USAGE in @CMD_SUB expects a String literal"))
                    sub_usage = n.args[3]
                    seen_sub_usage = true

                elseif mm == SYM_EPILOG
                    seen_sub_epilog && throw(ArgumentError("@CMD_EPILOG is duplicated in @CMD_SUB \"$sub_name\""))
                    length(n.args) >= 3 || throw(ArgumentError("@CMD_EPILOG in @CMD_SUB expects one String literal"))
                    n.args[3] isa String || throw(ArgumentError("@CMD_EPILOG in @CMD_SUB expects a String literal"))
                    sub_epilog = n.args[3]
                    seen_sub_epilog = true

                elseif mm == SYM_ALLOW
                    seen_sub_allow && throw(ArgumentError("@ALLOW_EXTRA is duplicated in @CMD_SUB \"$sub_name\""))
                    sub_allow_extra = true
                    seen_sub_allow = true
                end
            end

            if any(s.name == sub_name for s in normalized_sub_nodes)
                throw(ArgumentError("duplicate subcommand name: $(sub_name)"))
            end

            push!(normalized_sub_nodes, NormalizedSubCmd(
                name=sub_name,
                description=sub_desc,
                usage=sub_usage,
                epilog=sub_epilog,
                block=sub_block,
                allow_extra=sub_allow_extra
            ))
        else
            push!(main_nodes, node)
        end
    end

    main_block = Expr(:block, main_nodes...)
    fields, option_parse_stmts, positional_parse_stmts, post_stmts, argdefs_expr, gdefs = _compile_cmd_block(main_block)
    ctor_args = [f.args[1] for f in fields]

    sub_def_items, sub_parser_exprs, dispatch_branches, sub_help_branches, sub_names =
        _build_subcommand_bundle(normalized_sub_nodes, struct_name, ctor_args)

    _build_main_parser_expr(
        struct_name, usage, desc, epilog, allow_extra,
        fields, ctor_args, option_parse_stmts, positional_parse_stmts, post_stmts, argdefs_expr,
        gdefs, sub_def_items, sub_parser_exprs, dispatch_branches, sub_help_branches, sub_names
    )
end



"""
`parse_cli(::Type{T}, args::Vector{String}=ARGS) where T`

Parse command-line arguments into an instance of parser type `T`.

This is a convenience wrapper equivalent to calling `T(args)` directly, where
`T` is typically generated by `@CMD_MAIN`.

# Returns
An instance of `T` containing parsed argument fields and subcommand payload.

# Throws
- `ArgHelpRequested` if help is requested.
- `ArgParseError` on invalid input.
"""
parse_cli(::Type{T}, args::Vector{String}=ARGS; allow_empty_option_value::Bool=false) where {T} = begin
    if !(hasfield(T, :subcommand) && hasfield(T, :subcommand_args))
        throw(ArgumentError("parse_cli expects a @CMD_MAIN generated type"))
    end
    return T(args; allow_empty_option_value=allow_empty_option_value)
end


