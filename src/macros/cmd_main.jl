function _expect_string_literal_at(node::Expr, idx::Int, macro_name::String, expect_ctx::String="")
    length(node.args) >= idx || throw(ArgumentError(
        isempty(expect_ctx) ?
        "$(macro_name) expects one String literal" :
        "$(macro_name) in $(expect_ctx) expects one String literal"
    ))
    v = node.args[idx]
    v isa String || throw(ArgumentError(
        isempty(expect_ctx) ?
        "$(macro_name) expects a String literal" :
        "$(macro_name) in $(expect_ctx) expects a String literal"
    ))
    return v
end

function _parse_cmd_meta_block(
    block::Expr;
    initial_desc::String="",
    desc_predeclared::Bool=false,
    dup_ctx::String,
    expect_ctx::String=""
)
    usage = ""
    desc = initial_desc
    epilog = ""
    version = ""
    allow_extra = false

    seen_usage = false
    seen_desc = desc_predeclared || !isempty(initial_desc)
    seen_epilog = false
    seen_version = false
    seen_allow = false

    other_nodes = Expr[]

    for node in _getmacrocalls(block)
        m = _getmacroname(node)

        if m == SYM_USAGE
            seen_usage && throw(ArgumentError("@CMD_USAGE is duplicated in $(dup_ctx)"))
            usage = _expect_string_literal_at(node, 3, "@CMD_USAGE", expect_ctx)
            seen_usage = true

        elseif m == SYM_DESC
            seen_desc && throw(ArgumentError("@CMD_DESC is duplicated in $(dup_ctx)"))
            desc = _expect_string_literal_at(node, 3, "@CMD_DESC", expect_ctx)
            seen_desc = true

        elseif m == SYM_EPILOG
            seen_epilog && throw(ArgumentError("@CMD_EPILOG is duplicated in $(dup_ctx)"))
            epilog = _expect_string_literal_at(node, 3, "@CMD_EPILOG", expect_ctx)
            seen_epilog = true

        elseif m == SYM_VERSION
            seen_version && throw(ArgumentError("@CMD_VERSION is duplicated in $(dup_ctx)"))
            version = _expect_string_literal_at(node, 3, "@CMD_VERSION", expect_ctx)
            seen_version = true

        elseif m == SYM_ALLOW
            seen_allow && throw(ArgumentError("@ALLOW_EXTRA is duplicated in $(dup_ctx)"))
            allow_extra = true
            seen_allow = true

        else
            push!(other_nodes, node)
        end
    end

    return (usage=usage, desc=desc, epilog=epilog, version=version, allow_extra=allow_extra, other_nodes=other_nodes)
end

function _parse_sub_signature(node::Expr)
    length(node.args) >= 4 || throw(ArgumentError("@CMD_SUB expects \"name\" begin ... end or \"name\" \"desc\" begin ... end"))

    sub_name = node.args[3]
    sub_name isa String || throw(ArgumentError("@CMD_SUB name must be a String literal"))
    startswith(sub_name, "-") && throw(ArgumentError("@CMD_SUB name must not start with '-'"))

    sub_desc = ""
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
    return sub_name, sub_desc, sub_block
end

"""
    @CMD_MAIN TypeName begin
        ...
    end

Define a complete command-line interface schema and generate a concrete parser-backed result type.

`@CMD_MAIN` is the primary entry macro of RunicCLI's DSL. It compiles a declarative command specification
into a concrete Julia `struct`, a parser constructor for that type, subcommand-aware dispatch logic,
help/version integration, source-merge support (CLI/env/config), and compatibility with [`parse_cli`](@ref)
and [`run_cli`](@ref).

In practical terms, `@CMD_MAIN` lets you describe your CLI once using macros, and then obtain:

1. A generated result type `TypeName`.
2. A constructor  
   `TypeName(argv::Vector{String}=ARGS; allow_empty_option_value=false, env_prefix="", env=ENV, config=Dict(), config_file=nothing)`.
3. Built-in support for `-h` / `--help`.
4. Built-in support for `-V` / `--version` via `@CMD_VERSION`.
5. Main-command and subcommand parsing.
6. Typed fields representing parsed values.
7. Validation and argument-relationship enforcement.
8. Optional value sourcing from environment variables and config files.

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
MyCLI(
    argv::Vector{String}=ARGS;
    allow_empty_option_value::Bool=false,
    env_prefix::String="",
    env::AbstractDict=ENV,
    config::AbstractDict=Dict{String,Any}(),
    config_file::Union{Nothing,String}=nothing
)
```

This constructor performs parsing, validation, help/version detection, subcommand dispatch, and optional source merging.

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

- `@CMD_VERSION "..."`  
  Version text emitted when `-V` or `--version` is requested (before `--`).

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

#### `@ARG_DEF T default name flags... [help="..."] [help_name="..."]`

Declare an option with a default value.

- Result field type: `T`
- If the option is omitted, `default` is converted to `T`
- Help kind: `AK_OPTION`, `required=false`, `default=...`

#### `@ARG_OPT T name flags... [help="..."] [help_name="..."]`

Declare an optional single-valued option.

- Result field type: `Union{T,Nothing}`
- If omitted, the field becomes `nothing`

#### `@ARG_FLAG name flags... [help="..."] [help_name="..."]`

Declare a boolean switch.

- Result field type: `Bool`
- `true` if present at least once, otherwise `false`

#### `@ARG_COUNT name flags... [help="..."] [help_name="..."]`

Declare a counting flag.

- Result field type: `Int`
- Counts the number of occurrences across all declared aliases

#### `@ARG_MULTI T name flags... [help="..."] [help_name="..."]`

Declare a repeatable valued option.

- Result field type: `Vector{T}`
- All provided values are collected in occurrence order

### Positional arguments

#### `@POS_REQ T name [help="..."] [help_name="..."]`
Required positional (`T`)

#### `@POS_DEF T default name [help="..."] [help_name="..."]`
Defaulted positional (`T`)

#### `@POS_OPT T name [help="..."] [help_name="..."]`
Optional positional (`Union{T,Nothing}`)

#### `@POS_REST T name [help="..."] [help_name="..."]`
Rest positional (`Vector{T}`), must be last, and only one allowed

---

## Validation and constraints

### `@ARG_TEST name fn [msg]`

Apply a post-parse validator to a single argument (skip when value is `nothing`).

### `@ARG_STREAM name fn [msg]`

Apply validation element-wise for vector-like values, with scalar fallback.

### Built-in validator helpers

Use built-ins from `RunicCLI` to reduce manual lambdas:

- Numeric: [`v_min`](@ref), [`v_max`](@ref), [`v_range`](@ref)
- Set membership: [`v_oneof`](@ref), [`v_include`](@ref), [`v_exclude`](@ref)
- String/pattern: [`v_length`](@ref), [`v_prefix`](@ref), [`v_suffix`](@ref), [`v_regex`](@ref)
- Path checks: [`v_exists`](@ref), [`v_isfile`](@ref), [`v_isdir`](@ref), [`v_readable`](@ref), [`v_writable`](@ref)
- Composition: [`v_and`](@ref), [`v_or`](@ref)

See [`@ARG_TEST`](@ref) for examples of combining these helpers and writing custom validators.

### Relationship macros

- `@GROUP_EXCL a b c ...` — mutually exclusive explicit presence
- `@GROUP_INCL a b c ...` — at least one explicitly present
- `@ARG_REQUIRES anchor target1 target2 ...` — anchor requires one target
- `@ARG_CONFLICTS anchor target1 target2 ...` — anchor conflicts with targets

All are presence-based (explicitly provided), not final-value-based.

---

## Subcommands

Subcommands are declared via:

```julia
@CMD_SUB "name" begin
    ...
end

@CMD_SUB "name" "description" begin
    ...
end
```

Subcommand blocks support the same argument/validation/group macros, plus:

- `@CMD_DESC`
- `@CMD_USAGE`
- `@CMD_EPILOG`
- `@CMD_VERSION`
- `@ALLOW_EXTRA`

When selected:

- `subcommand` stores the name
- `subcommand_args` stores subcommand-local parsed values as `NamedTuple`

Subcommand help/version dispatch is context-aware.

---

## Parsing behavior

- `--` terminates option parsing.
- Help/version flags are recognized only before `--`.
- Required options/positionals are enforced.
- Values are converted to declared types.
- Relationship constraints are checked after parse/conversion.
- Unknown leftovers are rejected unless `@ALLOW_EXTRA` is enabled.
- Negative positional numbers may require `--` (e.g. `cmd -- -1`).

---

## Source merge behavior (CLI / config / env)

The generated constructor can merge additional sources before parse:

- `config_file` is loaded by [`load_config_file`](@ref)
- loaded config is merged with `config`
- final argument tokens are built by [`merge_cli_sources`](@ref)

Practical precedence for option-style values:

1. Explicit CLI tokens (highest)
2. `config` / `config_file` values
3. Environment variables (`env_prefix * uppercase(name)`)
4. Declared defaults in DSL (lowest)

---

## Help/version behavior

- `-h` / `--help` throws `ArgHelpRequested` with `CliDef` payload.
- `-V` / `--version` throws `ArgHelpRequested` carrying version message text.
- [`parse_cli`](@ref) and [`run_cli`](@ref) can render/finalize output.

---

## Shell completion

You can generate completion scripts from a `CliDef` via [`generate_completion`](@ref).

---

## Example

```julia
@CMD_MAIN MyCLI begin
    @CMD_DESC "Example CLI built with RunicCLI"
    @CMD_USAGE "mycli [OPTIONS] [SUBCOMMAND] [ARGS...]"
    @CMD_VERSION "mycli 1.2.3"

    @ARG_DEF Int 8080 port "-p" "--port" help="Server port"
    @ARG_MULTI String tag "-t" "--tag" help="Repeatable tag"
    @ARG_TEST port v_and(v_min(1), v_max(65535)) "port must be 1..65535"
    @ARG_STREAM tag v_length(min=1) "tag must be non-empty"

    @CMD_SUB "serve" "Run server" begin
        @CMD_VERSION "mycli serve 1.2.3"
        @ARG_REQ String host "--host"
    end
end
```

# See also

[`parse_cli`](@ref), [`run_cli`](@ref), [`render_help`](@ref),
[`@ARG_TEST`](@ref), [`@ARG_STREAM`](@ref),
[`load_config_file`](@ref), [`merge_cli_sources`](@ref), [`generate_completion`](@ref),
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

    main_meta = _parse_cmd_meta_block(
        block;
        initial_desc="",
        desc_predeclared=false,
        dup_ctx="@CMD_MAIN",
        expect_ctx=""
    )

    usage = main_meta.usage
    desc = main_meta.desc
    epilog = main_meta.epilog
    version = main_meta.version
    allow_extra = main_meta.allow_extra

    main_nodes = Expr[]
    normalized_sub_nodes = NormalizedSubCmd[]

    for node in main_meta.other_nodes
        m = _getmacroname(node)

        if m == SYM_SUB
            sub_name, sub_desc, sub_block = _parse_sub_signature(node)

            nonmacro_sub = _nonmacro_nodes(sub_block)
            if !isempty(nonmacro_sub)
                throw(ArgumentError("Only DSL macros are allowed inside @CMD_SUB block; found non-macro statement(s)"))
            end

            sub_meta = _parse_cmd_meta_block(
                sub_block;
                initial_desc=sub_desc,
                desc_predeclared=!isempty(sub_desc),
                dup_ctx="@CMD_SUB \"$(sub_name)\"",
                expect_ctx="@CMD_SUB \"$(sub_name)\""
            )

            if any(s.name == sub_name for s in normalized_sub_nodes)
                throw(ArgumentError("duplicate subcommand name: $(sub_name)"))
            end

            push!(normalized_sub_nodes, NormalizedSubCmd(
                name=sub_name,
                description=sub_meta.desc,
                usage=sub_meta.usage,
                epilog=sub_meta.epilog,
                version=sub_meta.version,
                block=Expr(:block, sub_meta.other_nodes...),
                allow_extra=sub_meta.allow_extra
            ))
        else
            push!(main_nodes, node)
        end
    end

    main_block = Expr(:block, main_nodes...)
    fields, option_parse_stmts, positional_parse_stmts, post_stmts, argdefs_expr, gdefs_excl, gdefs_incl, arg_requires_defs, arg_conflicts_defs = _compile_cmd_block(main_block)

    ctor_args = Symbol[f.args[1] for f in fields]

    sub_def_items, sub_parser_exprs, dispatch_branches, sub_help_branches, sub_version_branches, sub_names =
        _build_subcommand_bundle(normalized_sub_nodes, struct_name, ctor_args)


    _build_main_parser_expr(
        struct_name, usage, desc, epilog, version, allow_extra,
        fields, ctor_args, option_parse_stmts, positional_parse_stmts, post_stmts, argdefs_expr,
        gdefs_excl, gdefs_incl, arg_requires_defs, arg_conflicts_defs,
        sub_def_items, sub_parser_exprs, dispatch_branches, sub_help_branches, sub_version_branches, sub_names
    )
end
