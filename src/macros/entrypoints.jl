
"""
    @CMD_MAIN TypeName begin
        ...
    end

Define a complete command-line interface schema and generate a concrete parser-backed result type.

`@CMD_MAIN` is the primary entry macro of RunicCLI's DSL. It compiles a declarative command specification
into a concrete Julia `struct`, a parser constructor for that type, subcommand-aware dispatch logic,
help/version integration, source-merge support (CLI/env/config), and compatibility with [`clidef`](@ref)
and higher-level parsing or execution helpers built on top of the generated type.

In practical terms, `@CMD_MAIN` lets you describe your CLI once using macros, and then obtain:

1. A generated result type `TypeName`.
2. A constructor  
   `TypeName(argv::Vector{String}=ARGS; allow_empty_option_value=false, env=ENV, config=Dict(), config_file=nothing)`.
3. Built-in support for `-h` / `--help`.
4. Built-in support for `-V` / `--version` via `@CMD_VERSION`.
5. Main-command and subcommand parsing.
6. Typed fields representing parsed values.
7. Validation and argument-relationship enforcement.
8. Optional value sourcing from environment variables and config files.
9. Help-display grouping via `@ARG_GROUP`.
10. Final-value fallback resolution for optional value-bearing arguments via `fallback=...`.

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
    env::AbstractDict=ENV,
    config::AbstractDict=Dict{String,Any}(),
    config_file::Union{Nothing,String}=nothing
)
```

This constructor performs parsing, validation, help/version detection, subcommand dispatch, and optional source merging.

### 3. Static CLI definition registration

A `CliDef` is generated and registered for the produced type, making the command schema available to help,
rendering, completion, and related tooling through [`clidef`](@ref).

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
  If omitted, RunicCLI may use fallback/generated usage text depending on the renderer.

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
- Help kind: required option

#### `@ARG_OPT T name flags... [help="..."] [help_name="..."] [env="..."] [default=...] [fallback=other_arg]`

Declare an optional single-valued option.

- Result field type: `Union{T,Nothing}`
- Initial value resolution order:
  1. CLI
  2. environment via `env="..."`
  3. `default=...`
  4. `nothing`
- If the value is still `nothing`, `fallback=other_arg` may copy the final resolved value of another declared argument
- Fallback is final-value-based, not explicit-presence-based
- Fallback cycles are rejected

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

#### `@POS_OPT T name [help="..."] [help_name="..."] [env="..."] [default=...] [fallback=other_arg]`
Optional positional (`Union{T,Nothing}`) with the same fallback semantics as `@ARG_OPT`

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

All of the relation macros above are presence-based: they inspect whether arguments were explicitly provided,
not whether they acquired a final value through defaulting or fallback.

### Help-display grouping

- `@ARG_GROUP "title" a b c ...` — place arguments into a titled group for help rendering

`@ARG_GROUP` affects help presentation only. It does not change parse semantics, validation, or relationships.

Each argument may belong to at most one explicit help group within the same command block.

---

## Fallback semantics

Optional value-bearing arguments may declare `fallback=other_arg`.

This feature applies to:
- `@ARG_OPT`
- `@POS_OPT`

Fallback is evaluated after the argument's own CLI / env / default resolution has completed.

Conceptually:

```julia
final(self) =
    cli(self) ??
    env(self) ??
    default(self) ??
    fallback(final(other)) ??
    nothing
```

Properties:
- Fallback only applies when the current argument's resolved value is `nothing`.
- The fallback target may itself be populated from CLI, environment, default, or another fallback.
- Fallback targets must be declared arguments.
- Fallback is allowed only for optional value-bearing arguments.
- Fallback targets must be value-bearing non-rest arguments.
- Cycles such as `a -> b -> a` are rejected during macro expansion.

This makes fallback distinct from relation macros like `@ARG_REQUIRES`, which are based on explicit presence.

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

Subcommand blocks support the same argument, validation, grouping, and relation macros as the main command, plus:

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
- Fallback propagation is applied during post-processing for optional value-bearing arguments.
- Unknown leftovers are rejected unless `@ALLOW_EXTRA` is enabled.
- Negative positional numbers may require `--` (e.g. `cmd -- -1`).

---

## Source merge behavior (CLI / config / env)

The generated constructor can merge additional sources before parse:

- `config_file` is loaded by `load_config_file(config_file)`
- loaded config is merged into `config`
- final argument tokens are produced by `merge_cli_sources(...)`

Practical precedence for option-style values before DSL-level fallback:

1. Explicit CLI tokens
2. `config` / `config_file` values merged into CLI-like tokens
3. Environment variables referenced by `env="..."`
4. Declared defaults in the DSL
5. Fallback from another optional value-bearing argument
6. `nothing`

---

## Help/version behavior

- `-h` / `--help` throws `ArgHelpRequested` with `CliDef` payload.
- `-V` / `--version` throws `ArgHelpRequested` carrying version message text.
- Main-command and subcommand help definitions include argument metadata and argument-group metadata.
- Help renderers may use `@ARG_GROUP` metadata to organize arguments into titled sections.

---

## Example

```julia
@CMD_MAIN MyCLI begin
    @CMD_DESC "Example CLI built with RunicCLI"
    @CMD_USAGE "mycli [OPTIONS] [SUBCOMMAND] [ARGS...]"
    @CMD_VERSION "mycli 1.2.3"

    @ARG_OPT String config "--config" help="Path to config file"
    @ARG_OPT String output "--output" help="Primary output path"
    @ARG_OPT String dest "--dest" fallback=output help="Destination path; falls back to output"

    @ARG_OPT Int port "-p" "--port" env="MYCLI_PORT" default=8080 help="Server port"
    @ARG_MULTI String tag "-t" "--tag" help="Repeatable tag"
    @ARG_TEST port v_and(v_min(1), v_max(65535)) "port must be 1..65535"
    @ARG_STREAM tag v_length(min=1) "tag must be non-empty"

    @ARG_GROUP "Output" output dest
    @ARG_GROUP "Server Options" port tag

    @CMD_SUB "serve" "Run server" begin
        @CMD_VERSION "mycli serve 1.2.3"
        @ARG_REQ String host "--host"
        @ARG_FLAG reload "--reload"
        @ARG_GROUP "Serve Options" host reload
    end
end
```

# See also

[`@ARG_OPT`](@ref), [`@ARG_GROUP`](@ref), [`@ARG_TEST`](@ref), [`@ARG_STREAM`](@ref),
[`clidef`](@ref), [`render_help`](@ref), [`generate_completion`](@ref)
"""
macro CMD_MAIN(struct_name, block)
    return build_cmd_main_expr(struct_name, block)
end
