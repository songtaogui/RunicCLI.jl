# RunicCLI
# macros/placeholders.jl

@inline function _placeholder_macro_error(name::AbstractString)
    throw(ArgumentError(
        "$(name) can only be used inside @CMD_MAIN or @CMD_SUB blocks.\n" *
        "Example:\n" *
        "@CMD_MAIN MyCmd begin\n" *
        "    @ARG_FLAG verbose \"-v\" \"--verbose\" help=\"Enable verbose output\"\n" *
        "end"
    ))
end

"""
    @CMD_USAGE "USAGE TEXT"

Set a custom usage line for a command.

This macro is only valid inside a `@CMD_MAIN ... begin ... end` block or a
`@CMD_SUB ... begin ... end` block. The argument must be exactly one string
literal.

Behavior:
- In `@CMD_MAIN`, it defines the top-level command usage text.
- In `@CMD_SUB`, it defines the usage text for that subcommand.
- If omitted, usage is auto-generated from declared options/positionals/subcommands.

Constraints:
- Accepts one `String` literal.
- Duplicates in the same command scope are rejected.
- Not callable at runtime (placeholder macro outside DSL expansion).

Example:
```julia
@CMD_MAIN MyCLI begin
    @CMD_USAGE "mycli [OPTIONS] <input>"
    @ARG_FLAG verbose "-v" "--verbose" help="Enable verbose mode"
end
```

Subcommand example:
```julia
@CMD_SUB "build" begin
    @CMD_USAGE "mycli build [OPTIONS] <target>"
    @ARG_REQ String target "--target"
end
```
"""
macro CMD_USAGE(args...) _placeholder_macro_error("@CMD_USAGE") end

"""
    @CMD_DESC "DESCRIPTION"

Set the human-readable description for a command.

This macro is only valid inside a `@CMD_MAIN ... begin ... end` block or a
`@CMD_SUB ... begin ... end` block. The argument must be exactly one string
literal.

Behavior:
- In `@CMD_MAIN`, it sets the description shown in top-level help.
- In `@CMD_SUB`, it sets the description shown in subcommand help and list output.
- Description is rendered by help templates and may be wrapped depending on
  help formatting options.

Constraints:
- Accepts one `String` literal.
- Duplicates in the same command scope are rejected.
- Not callable at runtime (placeholder macro outside DSL expansion).

Example:
```julia
@CMD_MAIN MyCLI begin
    @CMD_DESC "A fast and script-friendly command line tool."
end
```

Subcommand example:
```julia
@CMD_SUB "clean" begin
    @CMD_DESC "Remove generated artifacts and caches."
end
```
"""
macro CMD_DESC(args...) _placeholder_macro_error("@CMD_DESC") end

"""
    @CMD_EPILOG "EPILOG TEXT"

Set the epilog text appended to the end of command help output.

This macro is only valid inside a `@CMD_MAIN ... begin ... end` block or a
`@CMD_SUB ... begin ... end` block. The argument must be exactly one string
literal.

Behavior:
- In `@CMD_MAIN`, it appears at the end of top-level help.
- In `@CMD_SUB`, it appears at the end of subcommand help.
- Useful for notes, examples, references, or environment hints.

Constraints:
- Accepts one `String` literal.
- Duplicates in the same command scope are rejected.
- Not callable at runtime (placeholder macro outside DSL expansion).

Example:
```julia
@CMD_MAIN MyCLI begin
    @CMD_EPILOG "Examples:\n  mycli run --config cfg.toml\n  mycli clean --all"
end
```

Subcommand example:
```julia
@CMD_SUB "run" begin
    @CMD_EPILOG "Tip: Use -- to pass positional values that start with '-'."
end
```
"""
macro CMD_EPILOG(args...) _placeholder_macro_error("@CMD_EPILOG") end

"""
    @CMD_VERSION "VERSION TEXT"

Set the version text for a command and enable version flag handling (`-V`, `--version`).

This macro is only valid inside a `@CMD_MAIN ... begin ... end` block or a
`@CMD_SUB ... begin ... end` block. The argument must be exactly one string
literal.

Behavior:
- In `@CMD_MAIN`, it defines the version text returned by top-level
  `-V` / `--version`.
- In `@CMD_SUB`, it defines the version text returned by subcommand
  `-V` / `--version` (when version is requested for that subcommand).
- Version flags are detected before `--` passthrough.
- If omitted, version output is an empty string unless provided by other sources
  (for example config overrides in your runtime flow).

Constraints:
- Accepts one `String` literal.
- Duplicates in the same command scope are rejected.
- Not callable at runtime (placeholder macro outside DSL expansion).

Example:
```julia
@CMD_MAIN MyCLI begin
    @CMD_VERSION "mycli 1.4.0"
end
```

Subcommand example:
```julia
@CMD_SUB "build" begin
    @CMD_VERSION "mycli build 1.4.0"
end
```
"""
macro CMD_VERSION(args...) _placeholder_macro_error("@CMD_VERSION") end


"""
    @CMD_SUB "name" begin ... end
    @CMD_SUB "name" "description" begin ... end

Declare a subcommand inside a `@CMD_MAIN ... begin ... end` block.

This macro is only valid within `@CMD_MAIN`. It creates a named subcommand with
its own argument DSL block, help metadata, and parse policy.

Behavior:
- Registers a subcommand under the top-level command.
- The subcommand name must be a string literal and must not start with `-`.
- Supports an optional inline description (`"description"`).
- Inside the subcommand block, you can use the same argument macros as main
  commands, plus:
  - `@CMD_DESC`
  - `@CMD_USAGE`
  - `@CMD_EPILOG`
  - `@ALLOW_EXTRA`
- If `-h`/`--help` appears in subcommand argv (before `--`), subcommand help is shown.
- Duplicate subcommand names in the same `@CMD_MAIN` are rejected.

Constraints:
- Valid only inside `@CMD_MAIN`.
- Accepted forms are exactly:
  - `@CMD_SUB "name" begin ... end`
  - `@CMD_SUB "name" "description" begin ... end`
- Subcommand body must be a `begin ... end` block containing only DSL macros.
- Not callable at runtime (placeholder macro outside DSL expansion).

Example:
```julia
@CMD_MAIN MyCLI begin
    @CMD_SUB "run" "Run a task" begin
        @CMD_USAGE "mycli run [OPTIONS] <target>"
        @ARG_REQ String target "--target" help="Target name"
        @ARG_FLAG dry_run "--dry-run" help="Do not execute actions"
    end
end
```
"""
macro CMD_SUB(args...) _placeholder_macro_error("@CMD_SUB") end

"""
    @ARG_REQ T name flags... [help="..."] [help_name="..."]

Declare a required option argument with a single value.

Behavior:
- Produces a field of type `T`.
- The option must be provided exactly once; missing value triggers a parse error.
- Multiple occurrences of the same logical option are rejected.
- Input text is converted using RunicCLI value parsing (`_parse_value`).

Constraints:
- `name` must be a symbol identifier.
- At least one flag is required.
- Flags must be string literals and valid option tokens (e.g. `"-p"`, `"--port"`).
- `help` and `help_name` must be string literals if provided.
- Flags must be globally unique across all option-style arguments in the same command.
- Not callable at runtime (placeholder macro outside DSL expansion).

Example:
```julia
@CMD_MAIN MyCLI begin
    @ARG_REQ Int port "-p" "--port" help="Port to bind" help_name="PORT"
end
```
"""
macro ARG_REQ(args...) _placeholder_macro_error("@ARG_REQ") end

"""
    @ARG_DEF T default name flags... [help="..."] [help_name="..."]

Declare an optional option argument with a default value.

Behavior:
- Produces a field of type `T`.
- If the option is not provided, `default` is converted to `T` via `convert(T, default)`.
- If provided, the input value is parsed as `T`.
- Multiple occurrences of the same logical option are rejected.

Constraints:
- `name` must be a symbol identifier.
- At least one flag is required.
- Flags must be string literals and valid option tokens.
- `default` must be convertible to `T`, otherwise command construction fails.
- `help` and `help_name` must be string literals if provided.
- Not callable at runtime (placeholder macro outside DSL expansion).

Example:
```julia
@CMD_MAIN MyCLI begin
    @ARG_DEF Int 8080 port "-p" "--port" help="Listening port"
end
```
"""
macro ARG_DEF(args...) _placeholder_macro_error("@ARG_DEF") end

"""
    @ARG_OPT T name flags... [help="..."] [help_name="..."]

Declare an optional option argument represented as `Union{T,Nothing}`.

Behavior:
- Produces a field of type `Union{T,Nothing}`.
- If omitted, value is `nothing`.
- If provided, the option value is parsed as `T`.
- Multiple occurrences of the same logical option are rejected.

Constraints:
- `name` must be a symbol identifier.
- At least one flag is required.
- Flags must be string literals and valid option tokens.
- `help` and `help_name` must be string literals if provided.
- Not callable at runtime (placeholder macro outside DSL expansion).

Example:
```julia
@CMD_MAIN MyCLI begin
    @ARG_OPT String config "--config" help="Optional config file path"
end
```
"""
macro ARG_OPT(args...) _placeholder_macro_error("@ARG_OPT") end

"""
    @ARG_FLAG name flags... [help="..."] [help_name="..."]

Declare a boolean switch option.

Behavior:
- Produces a field of type `Bool`.
- Value is `true` iff at least one listed flag appears in argv.
- Repeated occurrences are allowed; presence semantics remain boolean.
- Presence is tracked for mutual exclusion checks.

Constraints:
- `name` must be a symbol identifier.
- At least one flag is required.
- Flags must be string literals and valid option tokens.
- `help` and `help_name` must be string literals if provided.
- Not callable at runtime (placeholder macro outside DSL expansion).

Example:
```julia
@CMD_MAIN MyCLI begin
    @ARG_FLAG verbose "-v" "--verbose" help="Enable verbose logging"
end
```
"""
macro ARG_FLAG(args...) _placeholder_macro_error("@ARG_FLAG") end

"""
    @ARG_COUNT name flags... [help="..."] [help_name="..."]

Declare a counter option that counts flag occurrences.

Behavior:
- Produces a field of type `Int`.
- Each occurrence of any listed flag contributes `+1`.
- Useful for verbosity levels such as `-v -v -v`.
- Presence count is tracked precisely for mutual exclusion diagnostics.

Constraints:
- `name` must be a symbol identifier.
- At least one flag is required.
- Flags must be string literals and valid option tokens.
- `help` and `help_name` must be string literals if provided.
- Not callable at runtime (placeholder macro outside DSL expansion).

Example:
```julia
@CMD_MAIN MyCLI begin
    @ARG_COUNT verbose "-v" "--verbose" help="Increase verbosity"
end
```
"""
macro ARG_COUNT(args...) _placeholder_macro_error("@ARG_COUNT") end


"""
    @ARG_MULTI T name flags... [help="..."] [help_name="..."]

Declare a repeatable option that collects values into `Vector{T}`.

Behavior:
- Produces a field of type `Vector{T}`.
- Every occurrence of any listed flag consumes one value.
- All consumed values are parsed as `T` and appended in occurrence order.
- If omitted, result is an empty vector.

Constraints:
- `name` must be a symbol identifier.
- At least one flag is required.
- Flags must be string literals and valid option tokens.
- `help` and `help_name` must be string literals if provided.
- Not callable at runtime (placeholder macro outside DSL expansion).

Example:
```julia
@CMD_MAIN MyCLI begin
    @ARG_MULTI String include "-I" "--include" help="Include path(s)"
end
```
"""
macro ARG_MULTI(args...) _placeholder_macro_error("@ARG_MULTI") end

"""
    @POS_REQ T name [help="..."] [help_name="..."]

Declare a required positional argument.

Behavior:
- Produces a field of type `T`.
- Consumes the next positional token.
- Missing token triggers a parse error.
- Parsed using RunicCLI value parsing (`_parse_value`).

Constraints:
- `name` must be a symbol identifier.
- Only keyword metadata is allowed (`help`, `help_name`).
- Must appear before `@POS_REST` (if any).
- Not callable at runtime (placeholder macro outside DSL expansion).

Example:
```julia
@CMD_MAIN MyCLI begin
    @POS_REQ String input help="Input file path"
end
```
"""
macro POS_REQ(args...) _placeholder_macro_error("@POS_REQ") end

"""
    @POS_DEF T default name [help="..."] [help_name="..."]

Declare a positional argument with a default value.

Behavior:
- Produces a field of type `T`.
- If a positional token is available, it is parsed as `T`.
- Otherwise, `default` is converted to `T` via `convert(T, default)`.

Constraints:
- `name` must be a symbol identifier.
- Only keyword metadata is allowed (`help`, `help_name`).
- Must appear before `@POS_REST` (if any).
- Default must be convertible to `T`.
- Not callable at runtime (placeholder macro outside DSL expansion).

Example:
```julia
@CMD_MAIN MyCLI begin
    @POS_DEF Int 3 retries help="Retry count when omitted"
end
```
"""
macro POS_DEF(args...) _placeholder_macro_error("@POS_DEF") end

"""
    @POS_OPT T name [help="..."] [help_name="..."]

Declare an optional positional argument represented as `Union{T,Nothing}`.

Behavior:
- Produces a field of type `Union{T,Nothing}`.
- If a positional token is available, it is parsed as `T`.
- If not available, value is `nothing`.

Constraints:
- `name` must be a symbol identifier.
- Only keyword metadata is allowed (`help`, `help_name`).
- Must appear before `@POS_REST` (if any).
- Not callable at runtime (placeholder macro outside DSL expansion).

Example:
```julia
@CMD_MAIN MyCLI begin
    @POS_OPT String output help="Optional output path"
end
```
"""
macro POS_OPT(args...) _placeholder_macro_error("@POS_OPT") end

"""
    @POS_REST T name [help="..."] [help_name="..."]

Declare a variadic positional collector.

Behavior:
- Produces a field of type `Vector{T}`.
- Consumes all remaining positional tokens.
- Each token is parsed as `T`.
- Useful for pass-through tail arguments.

Constraints:
- `name` must be a symbol identifier.
- Only one `@POS_REST` is allowed per command scope.
- `@POS_REST` must be the last positional declaration.
- Only keyword metadata is allowed (`help`, `help_name`).
- Not callable at runtime (placeholder macro outside DSL expansion).

Example:
```julia
@CMD_MAIN MyCLI begin
    @POS_REST String files help="One or more input files"
end
```
"""
macro POS_REST(args...) _placeholder_macro_error("@POS_REST") end

"""
    @GROUP_EXCL a b c ...

Declare a mutually exclusive group of option-style arguments.

Behavior:
- Enforces that at most one listed argument is explicitly provided.
- Presence is based on parse-time provided tracking, not on runtime value equality.
- For count arguments (`@ARG_COUNT`), actual count is used in diagnostics.
- On violation, parsing fails with a detailed conflict message.

Constraints:
- Requires at least two argument names.
- Names must refer to previously declared arguments in the same command scope.
- Positional arguments are not allowed in exclusion groups.
- Duplicate names inside one group are rejected.
- Not callable at runtime (placeholder macro outside DSL expansion).

Example:
```julia
@CMD_MAIN MyCLI begin
    @ARG_FLAG json "--json"
    @ARG_FLAG yaml "--yaml"
    @GROUP_EXCL json yaml
end
```
"""
macro GROUP_EXCL(args...) _placeholder_macro_error("@GROUP_EXCL") end

"""
    @GROUP_INCL a b c ...

Declare a mutually inclusive group of option-style arguments.

Behavior:
- Enforces that at least one listed argument is explicitly provided.
- Presence is based on parse-time provided tracking, not on runtime value equality.
- For count arguments (`@ARG_COUNT`), actual count is used in diagnostics.
- On violation, parsing fails with an inclusion requirement message.

Constraints:
- Requires at least two argument names.
- Names must refer to previously declared arguments in the same command scope.
- Positional arguments are not allowed in inclusion groups.
- Duplicate names inside one group are rejected.
- Not callable at runtime (placeholder macro outside DSL expansion).

Example:
```julia
@CMD_MAIN MyCLI begin
    @ARG_FLAG json "--json"
    @ARG_FLAG yaml "--yaml"
    @GROUP_INCL json yaml
end
```
"""
macro GROUP_INCL(args...) _placeholder_macro_error("@GROUP_INCL") end

"""
    @ARG_REQUIRES anchor target1 target2 ...

Declare that one option-style argument requires at least one of a target set.

Behavior:
- If `anchor` is explicitly provided, at least one target argument must also be explicitly provided.
- Presence is based on parse-time provided tracking, not on final runtime values.
- For count arguments (`@ARG_COUNT`), occurrence count is used internally and reflected in diagnostics where applicable.
- On violation, parsing fails with a requirement message naming the anchor and its allowed targets.

Constraints:
- Requires one anchor argument name followed by at least one target argument name.
- All names must refer to previously declared arguments in the same command scope.
- The anchor must not also appear in the target list.
- Positional arguments are not allowed for the anchor or any target.
- Duplicate target names are rejected.
- Not callable at runtime (placeholder macro outside DSL expansion).

Example:
```julia
@CMD_MAIN MyCLI begin
    @ARG_FLAG auth "--auth"
    @ARG_FLAG token "--token"
    @ARG_FLAG user "--user"
    @ARG_REQUIRES auth token user
end
```
"""
macro ARG_REQUIRES(args...) _placeholder_macro_error("@ARG_REQUIRES") end

"""
    @ARG_CONFLICTS anchor target1 target2 ...

Declare that one option-style argument conflicts with a target set.

Behavior:
- If `anchor` is explicitly provided, none of the target arguments may be explicitly provided.
- Presence is based on parse-time provided tracking, not on final runtime values.
- For count arguments (`@ARG_COUNT`), occurrence count is included in conflict diagnostics.
- On violation, parsing fails with a detailed conflict message naming the conflicting targets that were seen.

Constraints:
- Requires one anchor argument name followed by at least one target argument name.
- All names must refer to previously declared arguments in the same command scope.
- The anchor must not also appear in the target list.
- Positional arguments are not allowed for the anchor or any target.
- Duplicate target names are rejected.
- Not callable at runtime (placeholder macro outside DSL expansion).

Example:
```julia
@CMD_MAIN MyCLI begin
    @ARG_FLAG stdin "--stdin"
    @ARG_FLAG file "--file"
    @ARG_FLAG url "--url"
    @ARG_CONFLICTS stdin file url
end
```
"""
macro ARG_CONFLICTS(args...) _placeholder_macro_error("@ARG_CONFLICTS") end


"""
    @ARG_TEST name fn [msg]

Declare a post-parse validator for a single argument value.

Behavior:
- Evaluates after parsing and type conversion.
- If the argument value is `nothing`, validation is skipped (treated as pass).
- Otherwise, requires `fn(value) == true`.
- On failure, parsing raises `ArgParseError`.
- If `msg` is provided, it must be a string literal and is used as custom error text.

Constraints:
- `name` must refer to an already declared argument.
- `fn` is required.
- Optional `msg` must be a string literal.
- Not callable at runtime (placeholder macro outside DSL expansion).

---

## Built-in validator helpers

`@ARG_TEST` works well with RunicCLI's built-ins:

### Numeric
- [`v_min(minv)`](@ref)
- [`v_max(maxv)`](@ref)
- [`v_range(lo, hi; closed=true)`](@ref)

### Membership
- [`v_oneof(xs)`](@ref)
- [`v_include(xs)`](@ref) (alias of `v_oneof`)
- [`v_exclude(xs)`](@ref)

### String / pattern
- [`v_length(; min=nothing, max=nothing, eq=nothing)`](@ref)
- [`v_prefix(prefix)`](@ref)
- [`v_suffix(suffix)`](@ref)
- [`v_regex(re::Regex)`](@ref)

### Path
- [`v_exists()`](@ref)
- [`v_isfile()`](@ref)
- [`v_isdir()`](@ref)
- [`v_readable()`](@ref)
- [`v_writable()`](@ref)

### Composition
- [`v_and(f1, f2, ...)`](@ref)
- [`v_or(f1, f2, ...)`](@ref)

---

## Examples

Built-in composition:

```julia
@ARG_TEST port v_and(v_min(1), v_max(65535)) "port must be in 1..65535"
@ARG_TEST mode v_oneof(["fast", "safe", "debug"]) "invalid mode"
@ARG_TEST input v_and(v_exists(), v_isfile(), v_readable()) "input must be a readable file"
```

Custom validator function:

```julia
is_even_positive(x) = x > 0 && iseven(x)
@ARG_TEST threads is_even_positive "threads must be a positive even integer"
```

Inline lambda:

```julia
@ARG_TEST name x -> length(strip(x)) > 0 "name cannot be blank"
```

For vector-like arguments with per-element checks, see [`@ARG_STREAM`](@ref).
"""
macro ARG_TEST(args...) _placeholder_macro_error("@ARG_TEST") end

"""
    @ARG_STREAM name fn [msg]

Declare element-wise validation for vector arguments, scalar validation otherwise.

Behavior:
- Evaluates after parsing and conversion.
- If the target value is a vector, every element must satisfy `fn`.
- If scalar and `nothing`, validation is skipped.
- If scalar and non-`nothing`, requires `fn(value) == true`.
- On failure, raises an argument parse error and reports failed values.

Constraints:
- `name` must refer to an already declared argument.
- `fn` is required.
- Optional `msg` must be a string literal.
- At most one custom message is allowed.
- Not callable at runtime (placeholder macro outside DSL expansion).

Example:
```julia
@CMD_MAIN MyCLI begin
    @ARG_MULTI Int ids "--id"
    @ARG_STREAM ids x -> x > 0 "all ids must be positive"
end
```
"""
macro ARG_STREAM(args...) _placeholder_macro_error("@ARG_STREAM") end

"""
    @ALLOW_EXTRA

Allow unconsumed/unknown trailing arguments in the current command scope.

Behavior:
- Disables strict leftover-argument rejection for that command (main or subcommand).
- Extra tokens that remain after declared option/positional parsing are accepted.
- Useful for pass-through wrappers and mixed parsing scenarios.

Constraints:
- Takes no arguments.
- May be used in `@CMD_MAIN` and inside `@CMD_SUB` blocks.
- Duplicate declarations in the same scope are rejected.
- Not callable at runtime (placeholder macro outside DSL expansion).

Example:
```julia
@CMD_MAIN MyCLI begin
    @ALLOW_EXTRA
    @ARG_FLAG verbose "--verbose"
end
```
"""
macro ALLOW_EXTRA(args...) _placeholder_macro_error("@ALLOW_EXTRA") end
