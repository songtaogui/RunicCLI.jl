"""
    @CMD_MAIN TypeName begin
        ...
    end

Define a complete command-line interface schema and generate a concrete parser-backed result type.

`@CMD_MAIN` is the primary entry macro of RunicCLI's DSL. It compiles a declarative command specification
into a concrete Julia `struct`, a parser constructor for that type, subcommand-aware dispatch logic,
help integration, and compatibility with [`parse_cli`](@ref) and [`run_cli`](@ref).

In practical terms, `@CMD_MAIN` lets you describe your CLI once using macros, and then obtain:

1. A generated result type `TypeName`.
2. A constructor `TypeName(argv::Vector{String}=ARGS; allow_empty_option_value=false)`.
3. Built-in support for `-h` / `--help`.
4. Main-command and subcommand parsing.
5. Typed fields representing parsed values.
6. Validation and argument-relationship enforcement.

---

## Generated artifacts

Given:

```julia
@CMD_MAIN MyCLI begin
    ...
end
```

RunicCLI generates:

### 1. A concrete result type

```julia
struct MyCLI
    ...
    subcommand::Union{Nothing,String}
    subcommand_args::Union{Nothing,NamedTuple}
end
```

All fields declared in the DSL are included first, followed by:

- `subcommand` — the selected subcommand name, or `nothing`
- `subcommand_args` — a `NamedTuple` payload for subcommand-specific parsed values, or `nothing`

### 2. A parsing constructor

```julia
MyCLI(argv::Vector{String}=ARGS; allow_empty_option_value=false)
```

This constructor performs all parsing, validation, help detection, and subcommand dispatch.

### 3. Integration with high-level APIs

The generated type is compatible with:

- [`parse_cli(MyCLI, args)`](@ref)
- [`run_cli(...)`](@ref)

---

## Block rules

The body of `@CMD_MAIN` must be a `begin ... end` block.

Only RunicCLI DSL macros are allowed inside the block. Any non-macro statement is rejected at macro-expansion time.

This restriction is intentional: the block is treated as a schema declaration, not as executable code.

---

## Supported declarations inside `@CMD_MAIN`

### Command metadata

- `@CMD_USAGE "..."`  
  Provide a custom usage string shown in help output.  
  If omitted, RunicCLI auto-generates a fallback usage line from the declared schema.

- `@CMD_DESC "..."`  
  Command description shown in help output.

- `@CMD_EPILOG "..."`  
  Trailing help text shown after all argument and subcommand sections.

- `@ALLOW_EXTRA`  
  Allow unknown or leftover arguments to remain unconsumed instead of producing an error.

Each metadata macro may appear at most once in the main block.

---

## Supported argument declarations

### Option-style arguments

#### `@ARG_REQ T name flags... [help="..."] [help_name="..."]`

Declare a required single-valued option.

- Result field type: `T`
- Parsing requirement: one of the declared flags must appear with a value
- Help kind: `AK_OPTION`, `required=true`

Example:

```julia
@ARG_REQ String host "--host" help="Bind host"
```

#### `@ARG_DEF T default name flags... [help="..."] [help_name="..."]`

Declare an option with a default value.

- Result field type: `T`
- If the option is omitted, `default` is converted to `T`
- Help kind: `AK_OPTION`, `required=false`, `default=...`

Example:

```julia
@ARG_DEF Int 8080 port "-p" "--port" help="Server port"
```

#### `@ARG_OPT T name flags... [help="..."] [help_name="..."]`

Declare an optional single-valued option.

- Result field type: `Union{T,Nothing}`
- If omitted, the field becomes `nothing`

Example:

```julia
@ARG_OPT String config "--config" help="Optional config path"
```

#### `@ARG_FLAG name flags... [help="..."] [help_name="..."]`

Declare a boolean switch.

- Result field type: `Bool`
- `true` if present at least once, otherwise `false`

Example:

```julia
@ARG_FLAG verbose "-v" "--verbose" help="Enable verbose output"
```

#### `@ARG_COUNT name flags... [help="..."] [help_name="..."]`

Declare a counting flag.

- Result field type: `Int`
- Counts the number of occurrences across all declared aliases

Example:

```julia
@ARG_COUNT quiet "-q" "--quiet" help="Reduce output; repeat for stronger effect"
```

#### `@ARG_MULTI T name flags... [help="..."] [help_name="..."]`

Declare a repeatable valued option.

- Result field type: `Vector{T}`
- All provided values are collected in occurrence order

Example:

```julia
@ARG_MULTI String tag "-t" "--tag" help="Repeatable tag"
```

---

### Positional arguments

#### `@POS_REQ T name [help="..."] [help_name="..."]`

Declare a required positional argument.

- Result field type: `T`
- Must be present or parsing fails

Example:

```julia
@POS_REQ String input help="Input file"
```

#### `@POS_DEF T default name [help="..."] [help_name="..."]`

Declare a positional with a default value.

- Result field type: `T`
- Uses `default` if omitted

Example:

```julia
@POS_DEF String "fast" mode help="Execution mode"
```

#### `@POS_OPT T name [help="..."] [help_name="..."]`

Declare an optional positional.

- Result field type: `Union{T,Nothing}`
- Becomes `nothing` if omitted

Example:

```julia
@POS_OPT String profile help="Optional profile name"
```

#### `@POS_REST T name [help="..."] [help_name="..."]`

Declare a "rest" positional that consumes all remaining positional tokens.

- Result field type: `Vector{T}`
- Must be the last positional declaration
- Only one `@POS_REST` is allowed

Example:

```julia
@POS_REST String extras help="Additional arguments"
```

---

## Validation and constraints

### `@ARG_TEST name fn [msg]`

Apply a post-parse validator to a single argument.

- The validator is skipped when the value is `nothing`
- If validation fails, parsing throws `ArgParseError`
- `msg`, if supplied, must be a string literal

Example:

```julia
@ARG_TEST port x -> x > 0 "Port must be positive"
```

### `@ARG_STREAM name fn [msg]`

Apply validation element-wise for vector-like values, with scalar fallback.

Behavior:

- if the target value is a vector, each element is validated,
- if the target is scalar and not `nothing`, the scalar is validated,
- all failing values are included in the generated error message.

Example:

```julia
@ARG_STREAM tag x -> !isempty(x) "Tags must be non-empty"
```

### `@GROUP_EXCL a b c ...`

Declare a mutually exclusive group by explicit presence.

Rules:

- requires at least two argument names,
- all names must refer to previously declared arguments,
- only option-style arguments are allowed,
- exclusivity is determined by whether arguments were explicitly provided, not by their final value.

For example, two defaulted options are not considered conflicting unless both were explicitly passed.

Example:

```julia
@GROUP_EXCL verbose quiet
```

### `@GROUP_INCL a b c ...`

Declare a mutually inclusive presence group for option-style arguments.

Rules:

- requires at least two argument names,
- all names must refer to previously declared arguments,
- only option-style arguments are allowed,
- inclusion is determined by whether arguments were explicitly provided, not by their final value,
- parsing fails if none of the listed arguments was explicitly passed.

Example:

```julia
@GROUP_INCL json yaml
```

### `@ARG_REQUIRES anchor target1 target2 ...`

Declare that one option-style argument requires at least one of a target set.

Rules:

- all names must refer to previously declared arguments,
- only option-style arguments are allowed,
- the anchor must not appear in the target list,
- at least one target must be listed,
- the requirement is checked by explicit presence, not by final value.

This is useful for relationships such as "if `--auth` is used, then at least one of `--token` or `--user` must also be present".

Example:

```julia
@ARG_REQUIRES auth token user
```

### `@ARG_CONFLICTS anchor target1 target2 ...`

Declare that one option-style argument conflicts with a target set.

Rules:

- all names must refer to previously declared arguments,
- only option-style arguments are allowed,
- the anchor must not appear in the target list,
- at least one target must be listed,
- conflicts are checked by explicit presence, not by final value.

This is useful for relationships such as "`--stdin` cannot be combined with `--file` or `--url`".

Example:

```julia
@ARG_CONFLICTS stdin file url
```

---

## Subcommands

Subcommands are declared using `@CMD_SUB` inside `@CMD_MAIN`:

```julia
@CMD_SUB "name" begin
    ...
end

@CMD_SUB "name" "description" begin
    ...
end
```

Each subcommand has:

- a required string name,
- an optional inline description,
- its own `begin ... end` block containing supported DSL macros.

### Supported content in subcommands

Inside a subcommand block, you can declare:

- `@CMD_DESC`
- `@CMD_USAGE`
- `@CMD_EPILOG`
- `@ALLOW_EXTRA`
- all argument declarations
- `@ARG_TEST`
- `@ARG_STREAM`
- `@GROUP_EXCL`
- `@GROUP_INCL`
- `@ARG_REQUIRES`
- `@ARG_CONFLICTS`

Subcommands are normalized and compiled into dedicated sub-parsers. The selected subcommand's result
is stored in:

- `subcommand` as the subcommand name,
- `subcommand_args` as a `NamedTuple` of subcommand-local parsed values.

### Help for subcommands

If help is requested after a subcommand selection, RunicCLI renders subcommand-specific help using
that subcommand's own definition, usage, description, epilog, and arguments.

---

## Parsing behavior

The generated parser implements the following semantics.

### Option splitting and `--`

- `--` terminates option parsing.
- Tokens after `--` are treated as positional.
- Help flags are only considered before `--`.

### Short flag handling

Short bundles such as `-abc` may be interpreted as grouped short flags where supported by the underlying parser utilities.

### Requiredness

- Required options and required positionals are enforced.
- Omitted required arguments cause `ArgParseError`.

### Type conversion

Values are converted to declared types using RunicCLI's value parsing utilities. Conversion follows package logic such as:

- parsing where appropriate,
- constructor fallback where appropriate,
- default conversion for `@ARG_DEF` / `@POS_DEF`.

### Argument relationship checks

After basic parsing and conversion, RunicCLI applies any declared relationship constraints, including:

- mutual exclusion via `@GROUP_EXCL`,
- at-least-one presence via `@GROUP_INCL`,
- dependency checks via `@ARG_REQUIRES`,
- conflict checks via `@ARG_CONFLICTS`.

These checks are based on whether an argument was explicitly provided during parsing.

### Unknown arguments

By default:

- unexpected option-like leftovers are rejected,
- remaining unexpected arguments are rejected.

If `@ALLOW_EXTRA` is present for the current command level, leftover arguments are tolerated.

### Negative positional numbers

Tokens like `-1` may be ambiguous with options. Users may need to write:

```bash
cmd -- -1
```

to force such values to be interpreted as positional arguments.

---

## Help behavior

The generated constructor recognizes `-h` and `--help` before `--`.

### Main help

If help is requested at the main-command level, the constructor throws:

```julia
ArgHelpRequested(def, path)
```

where `def` is a full [`CliDef`](@ref) describing the main command, including subcommands and declared constraints.

### Subcommand help

If a subcommand is selected and help is requested in that subcommand context, the constructor throws
an `ArgHelpRequested` for the subcommand-specific [`CliDef`](@ref).

High-level wrappers such as [`parse_cli`](@ref) and [`run_cli`](@ref) can then render this into final text.

---

## Result field mapping

The generated result type uses these field types:

- `@ARG_REQ T`          → `T`
- `@ARG_DEF T ...`      → `T`
- `@ARG_OPT T`          → `Union{T,Nothing}`
- `@ARG_FLAG`           → `Bool`
- `@ARG_COUNT`          → `Int`
- `@ARG_MULTI T`        → `Vector{T}`

- `@POS_REQ T`          → `T`
- `@POS_DEF T ...`      → `T`
- `@POS_OPT T`          → `Union{T,Nothing}`
- `@POS_REST T`         → `Vector{T}`

Additionally:

- `subcommand`          → `Union{Nothing,String}`
- `subcommand_args`     → `Union{Nothing,NamedTuple}`

---

## Compile-time validation performed by the macro

`@CMD_MAIN` performs a substantial amount of schema validation during macro expansion.

Examples of invalid declarations include:

- duplicate argument names,
- duplicate flag aliases across arguments,
- duplicate `@CMD_USAGE`, `@CMD_DESC`, `@CMD_EPILOG`, or `@ALLOW_EXTRA`,
- duplicate subcommand names,
- invalid flag shapes,
- non-string flag literals,
- `@POS_REST` not placed last,
- more than one `@POS_REST`,
- validators referencing unknown arguments,
- `@GROUP_EXCL`, `@GROUP_INCL` referencing unknown arguments,
- `@GROUP_EXCL`, `@GROUP_INCL` applied to positional arguments,
- `@ARG_REQUIRES`, `@ARG_CONFLICTS` referencing unknown arguments,
- `@ARG_REQUIRES`, `@ARG_CONFLICTS` applied to positional arguments,
- `@ARG_REQUIRES`, `@ARG_CONFLICTS` with duplicate targets,
- `@ARG_REQUIRES`, `@ARG_CONFLICTS` where the anchor appears among the targets,
- non-macro statements inside the block.

This design makes many CLI-definition mistakes fail early at compile time rather than at runtime.

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
    @ARG_FLAG json "--json" help="Emit JSON output"
    @ARG_FLAG yaml "--yaml" help="Emit YAML output"
    @ARG_FLAG auth "--auth" help="Enable authenticated mode"
    @ARG_FLAG token "--token" help="Use token-based authentication"
    @ARG_FLAG user "--user" help="Use user credentials"

    @POS_REQ String input help="Input file"
    @POS_OPT String mode help="Run mode"
    @POS_REST String extras help="Additional positional arguments"

    @ARG_TEST port x -> x > 0 "Port must be positive"
    @ARG_STREAM tag x -> !isempty(x) "Tags must be non-empty"

    @GROUP_EXCL verbose quiet
    @GROUP_INCL json yaml
    @ARG_REQUIRES auth token user
    @ARG_CONFLICTS config input

    @CMD_SUB "serve" "Run server" begin
        @ARG_FLAG daemon "-d" "--daemon" help="Run in background"
        @ARG_REQ String host "--host" help="Bind host"
        @ARG_FLAG stdin "--stdin" help="Read from stdin"
        @ARG_FLAG file "--file" help="Read from file"
        @ARG_FLAG url "--url" help="Read from URL"
        @ARG_CONFLICTS stdin file url
    end
end
```

Usage:

```julia
opts = parse_cli(MyCLI, ["--port", "9000", "--json", "input.txt"])

code = run_cli() do
    o = parse_cli(MyCLI)
    # application logic
end
```

---

## Notes

- `TypeName` must be a plain symbol; dotted names are not supported.
- `@CMD_MAIN` is the top-level DSL entry point for defining a parseable command type.
- The macro is declarative: do not place arbitrary Julia statements inside the block.
- Subcommand payloads are stored as `NamedTuple`s rather than dedicated generated subcommand types.

# See also

[`parse_cli`](@ref), [`run_cli`](@ref), [`render_help`](@ref), [`ArgKind`](@ref),
[`build_help_template`](@ref)
"""
macro CMD_MAIN(struct_name, block)
    if !(block isa Expr && block.head == :block)
        throw(ArgumentError("@CMD_MAIN expects a `begin ... end` block as second argument"))
    end

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
    fields, option_parse_stmts, positional_parse_stmts, post_stmts, argdefs_expr, gdefs_excl, gdefs_incl, arg_requires_defs, arg_conflicts_defs = _compile_cmd_block(main_block)

    ctor_args = Symbol[f.args[1] for f in fields]

    sub_def_items, sub_parser_exprs, dispatch_branches, sub_help_branches, sub_names =
        _build_subcommand_bundle(normalized_sub_nodes, struct_name, ctor_args)

    _build_main_parser_expr(
        struct_name, usage, desc, epilog, allow_extra,
        fields, ctor_args, option_parse_stmts, positional_parse_stmts, post_stmts, argdefs_expr,
        gdefs_excl, gdefs_incl, arg_requires_defs, arg_conflicts_defs,
        sub_def_items, sub_parser_exprs, dispatch_branches, sub_help_branches, sub_names
    )
end