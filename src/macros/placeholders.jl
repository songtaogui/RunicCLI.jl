
@inline function _placeholder_macro_error(name::AbstractString)
    throw(ArgumentError(
        "$(name) can only be used inside @CMD_MAIN or @CMD_SUB blocks.\n" *
        "See `@doc $(name)` for details."
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
    @CMD_AUTOHELP

Enable automatic help display when a command or subcommand is invoked with no effective arguments.

Behavior:
- When used inside `@CMD_MAIN`, invoking the command with an empty `argv` triggers help immediately.
- Help is also triggered after config/environment merging if the resulting argument list is still empty.
- When used inside `@CMD_SUB`, invoking that subcommand without any remaining subcommand arguments triggers subcommand help.
- Explicit `-h` / `--help` handling remains supported independently of this macro.
- This macro only enables empty-input help behavior; it does not change argument parsing rules, validation logic, or subcommand dispatch semantics.

Constraints:
- May only appear inside `@CMD_MAIN begin ... end` or `@CMD_SUB ... begin ... end` blocks.
- At most one `@CMD_AUTOHELP` may appear within the same command scope.
- Repeated use in the same command or subcommand block is rejected.
- Not callable at runtime (placeholder macro outside DSL expansion).

Example:
```julia
@CMD_MAIN MyCLI begin
    @CMD_DESC "Example CLI"
    @CMD_AUTOHELP

    @ARG_FLAG verbose "-v" "--verbose"

    @CMD_SUB "serve" begin
        @CMD_DESC "Run the server"
        @CMD_AUTOHELP
        @ARG_OPT Int port "--port" default=8080
    end
end
```

With this configuration:
- `MyCLI([])` shows main command help.
- `MyCLI(["serve"])` shows help for the `serve` subcommand.
- `MyCLI(["--help"])` and `MyCLI(["serve", "--help"])` still show help explicitly.
"""
macro CMD_AUTOHELP(args...) _placeholder_macro_error("@CMD_AUTOHELP") end

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
    @ARG_REQ T name flags... [help="..."] [help_name="..."] [vfun=...] [vmsg="..."]

Declare a required option argument with a single value.

Behavior:
- Produces a field of type `T`.
- The option must be provided exactly once; missing value triggers a parse error.
- Multiple occurrences of the same logical option are rejected.
- Input text is converted using RunicCLI value parsing (`_parse_value`).
- If `vfun` is provided, post-parse validation is applied as `vfun(value) == true`.
- If `vmsg` is provided, it is used as custom failure text.
- `vmsg` requires `vfun`.

Constraints:
- `name` must be a symbol identifier.
- At least one flag is required.
- Flags must be string literals and valid option tokens (e.g. `"-p"`, `"--port"`).
- `help`, `help_name`, and `vmsg` must be string literals if provided.
- `help_name` must be non-empty and single-line.
- Flags must be globally unique across all option-style arguments in the same command.
- Not callable at runtime (placeholder macro outside DSL expansion).

Example:
```julia
@CMD_MAIN MyCLI begin
    @ARG_REQ Int port "-p" "--port" help="Port to bind" help_name="PORT"
    @ARG_REQ Int threads "--threads" vfun=V_num_min(1) vmsg="threads must be >= 1"
end
```
"""
macro ARG_REQ(args...) _placeholder_macro_error("@ARG_REQ") end


"""
    @ARG_OPT T name flags... [help="..."] [help_name="..."] [env="..."] [default=...] [fallback=other_arg] [vfun=...] [vmsg="..."]

Declare an optional single-valued option argument.

Behavior:
- Produces a field of type `Union{T,Nothing}`.
- Value resolution is performed in this order:
  1. CLI option value, if the option is present
  2. Environment variable value from `env="..."`
  3. `default=...`
  4. `nothing`
- After that initial resolution, if the final value is still `nothing` and `fallback=other_arg` is provided,
  the argument takes the final resolved value of `other_arg`.
- CLI input and environment input are parsed as `T`.
- `default` is converted to `T` using RunicCLI default conversion.
- Multiple occurrences of the same logical option are rejected.
- If `vfun` is provided, validation is applied only when value is non-`nothing`.
- If `vmsg` is provided, it is used as custom failure text.
- `vmsg` requires `vfun`.

Fallback semantics:
- `fallback` refers to another declared argument by symbol name.
- Fallback is final-value-based, not explicit-presence-based.
- This means the fallback target may itself have been populated from CLI, environment, default, or its own fallback chain.
- Fallback is applied only when the current argument resolves to `nothing`.
- Fallback chains are allowed, but fallback cycles are rejected at macro-expansion time.

Constraints:
- `name` must be a symbol identifier.
- At least one flag is required.
- Flags must be string literals and valid option tokens.
- Supported keywords are `help`, `help_name`, `env`, `default`, `fallback`, `vfun`, and `vmsg`.
- `help`, `help_name`, `env`, and `vmsg` must be string literals if provided.
- `help_name` must be non-empty and single-line.
- `env` must be non-empty.
- `fallback` must be a symbol identifier naming another declared argument.
- `vmsg` requires `vfun`.
- Fallback is supported only for optional value-bearing arguments.
- The fallback target must be a value-bearing non-rest argument.
- Not callable at runtime (placeholder macro outside DSL expansion).

Examples:
```julia
@CMD_MAIN MyCLI begin
    @ARG_OPT String config "--config" help="Optional config file path"
    @ARG_OPT Int port "-p" "--port" env="MYCLI_PORT" default=8080 help="Port to bind"
end
```

Using fallback:
```julia
@CMD_MAIN MyCLI begin
    @ARG_OPT String output "--output" help="Primary output path"
    @ARG_OPT String dest "--dest" fallback=output help="Alias that falls back to output"
end
```

Fallback chain:
```julia
@CMD_MAIN MyCLI begin
    @ARG_OPT String c "--c"
    @ARG_OPT String b "--b" fallback=c
    @ARG_OPT String a "--a" fallback=b
end
```
"""
macro ARG_OPT(args...) _placeholder_macro_error("@ARG_OPT") end

"""
    @ARG_FLAG name flags... [help="..."] [help_name="..."] [vfun=...] [vmsg="..."]

Declare a boolean switch option.

Behavior:
- Produces a field of type `Bool`.
- Value is `true` iff at least one listed flag appears in argv.
- Repeated occurrences are allowed; presence semantics remain boolean.
- Presence is tracked for mutual exclusion checks.
- If `vfun` is provided, post-parse validation is applied as `vfun(value) == true`.
- If `vmsg` is provided, it is used as custom failure text.
- `vmsg` requires `vfun`.

Constraints:
- `name` must be a symbol identifier.
- At least one flag is required.
- Flags must be string literals and valid option tokens.
- `help`, `help_name`, and `vmsg` must be string literals if provided.
- `help_name` must be non-empty and single-line.
- `vmsg` requires `vfun`.
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
    @ARG_COUNT name flags... [help="..."] [help_name="..."] [vfun=...] [vmsg="..."]

Declare a counter option that counts flag occurrences.

Behavior:
- Produces a field of type `Int`.
- Each occurrence of any listed flag contributes `+1`.
- Useful for verbosity levels such as `-v -v -v`.
- Presence count is tracked precisely for mutual exclusion diagnostics.
- If `vfun` is provided, post-parse validation is applied as `vfun(value) == true`.
- If `vmsg` is provided, it is used as custom failure text.
- `vmsg` requires `vfun`.

Constraints:
- `name` must be a symbol identifier.
- At least one flag is required.
- Flags must be string literals and valid option tokens.
- `help`, `help_name`, and `vmsg` must be string literals if provided.
- `help_name` must be non-empty and single-line.
- `vmsg` requires `vfun`.
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
    @ARG_MULTI T name flags... [help="..."] [help_name="..."] [vfun=...] [vmsg="..."]

Declare a repeatable option that collects values into `Vector{T}`.

Behavior:
- Produces a field of type `Vector{T}`.
- Every occurrence of any listed flag consumes one value.
- All consumed values are parsed as `T` and appended in occurrence order.
- If omitted, result is an empty vector.
- If `vfun` is provided, post-parse validation is applied element-wise: every collected value must satisfy `vfun`.
- If `vmsg` is provided, it is used as custom failure text.
- `vmsg` requires `vfun`.

Constraints:
- `name` must be a symbol identifier.
- At least one flag is required.
- Flags must be string literals and valid option tokens.
- `help`, `help_name`, and `vmsg` must be string literals if provided.
- `help_name` must be non-empty and single-line.
- `vmsg` requires `vfun`.
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
    @POS_REQ T name [help="..."] [help_name="..."] [vfun=...] [vmsg="..."]

Declare a required positional argument.

Behavior:
- Produces a field of type `T`.
- Consumes the next positional token.
- Missing token triggers a parse error.
- Parsed using RunicCLI value parsing (`_parse_value`).
- If `vfun` is provided, post-parse validation is applied as `vfun(value) == true`.
- If `vmsg` is provided, it is used as custom failure text.
- `vmsg` requires `vfun`.

Constraints:
- `name` must be a symbol identifier.
- Only keyword metadata is allowed (`help`, `help_name`, `vfun`, `vmsg`).
- `help`, `help_name`, and `vmsg` must be string literals if provided.
- `help_name` must be non-empty and single-line.
- `vmsg` requires `vfun`.
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
    @POS_OPT T name [help="..."] [help_name="..."] [env="..."] [default=...] [fallback=other_arg] [vfun=...] [vmsg="..."]

Declare an optional positional argument.

Behavior:
- Produces a field of type `Union{T,Nothing}`.
- Value resolution order is:
  1. Next positional token, if available
  2. Environment variable value from `env="..."`
  3. `default=...`
  4. `nothing`
- CLI input and environment input are parsed as `T`.
- `default` is converted to `T` using RunicCLI default conversion.
- If `fallback=other_arg` is provided and the value is still `nothing`, this argument takes the final resolved value of `other_arg`.
- If `vfun` is provided, validation is applied only when value is non-`nothing`.
- If `vmsg` is provided, it is used as custom failure text.
- `vmsg` requires `vfun`.

Constraints:
- `name` must be a symbol identifier.
- Only keyword metadata is allowed (`help`, `help_name`, `env`, `default`, `fallback`, `vfun`, `vmsg`).
- `help`, `help_name`, `env`, and `vmsg` must be string literals if provided.
- `help_name` must be non-empty and single-line.
- `env` must be non-empty.
- `fallback` must be a symbol identifier naming another declared argument.
- `vmsg` requires `vfun`.
- Must appear before `@POS_REST` (if any).
- Not callable at runtime (placeholder macro outside DSL expansion).

Example:
```julia
@CMD_MAIN MyCLI begin
    @POS_OPT String output help="Optional output path"
    @POS_OPT Int threads env="MYCLI_THREADS" default=4 help="Worker thread count"
end
```
"""
macro POS_OPT(args...) _placeholder_macro_error("@POS_OPT") end

"""
    @POS_REST T name [help="..."] [help_name="..."] [vfun=...] [vmsg="..."]

Declare a variadic positional collector.

Behavior:
- Produces a field of type `Vector{T}`.
- Consumes all remaining positional tokens.
- Each token is parsed as `T`.
- Useful for pass-through tail arguments.
- If `vfun` is provided, post-parse validation is applied element-wise: every collected value must satisfy `vfun`.
- If `vmsg` is provided, it is used as custom failure text.
- `vmsg` requires `vfun`.

Constraints:
- `name` must be a symbol identifier.
- Only one `@POS_REST` is allowed per command scope.
- `@POS_REST` must be the last positional declaration.
- Only keyword metadata is allowed (`help`, `help_name`, `vfun`, `vmsg`).
- `help`, `help_name`, and `vmsg` must be string literals if provided.
- `help_name` must be non-empty and single-line.
- `vmsg` requires `vfun`.
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
    @ARGREL_ATMOSTONE a b c ... [help="..."]

Declare a cardinality constraint for a set of option-style arguments.

Behavior:
- Enforces that at most one listed argument is considered present.
- Presence is based on parse-time provided tracking, not on final runtime value equality.
- For count arguments (`@ARG_COUNT`), an argument is considered present when its observed count is greater than zero.
- If more than one listed argument is present, parsing fails with a default message, or with the custom `help="..."` message when provided.

Constraints:
- Requires at least one argument name.
- All names must refer to previously declared arguments in the same command scope.
- Only option-style arguments are allowed; positional arguments are rejected.
- Duplicate names are rejected.
- Accepts at most one `help="..."` keyword, and the help text must be a String literal.
- Although one name is technically accepted, this relation is typically meaningful only with two or more names.
- Not callable at runtime; this macro is only valid inside `@CMD_MAIN` or `@CMD_SUB` blocks.

Example:
```julia
@CMD_MAIN MyCLI begin
    @ARG_FLAG json "--json"
    @ARG_FLAG yaml "--yaml"
    @ARG_FLAG toml "--toml"

    @ARGREL_ATMOSTONE json yaml toml
end
```
"""
macro ARGREL_ATMOSTONE(args...) _placeholder_macro_error("@ARGREL_ATMOSTONE") end

"""
    @ARGREL_ATLEASTONE a b c ... [help="..."]

Declare a cardinality constraint requiring at least one of a set of option-style arguments.

Behavior:
- Enforces that at least one listed argument is considered present.
- Presence is based on parse-time provided tracking, not on final runtime value equality.
- For count arguments (`@ARG_COUNT`), an argument is considered present when its observed count is greater than zero.
- If none of the listed arguments is present, parsing fails with a default message, or with the custom `help="..."` message when provided.

Constraints:
- Requires at least one argument name.
- All names must refer to previously declared arguments in the same command scope.
- Only option-style arguments are allowed; positional arguments are rejected.
- Duplicate names are rejected.
- Accepts at most one `help="..."` keyword, and the help text must be a String literal.
- Although one name is technically accepted, this relation is typically most useful with two or more names.
- Not callable at runtime; this macro is only valid inside `@CMD_MAIN` or `@CMD_SUB` blocks.

Example:
```julia
@CMD_MAIN MyCLI begin
    @ARG_FLAG json "--json"
    @ARG_FLAG yaml "--yaml"

    @ARGREL_ATLEASTONE json yaml
end
```
"""
macro ARGREL_ATLEASTONE(args...) _placeholder_macro_error("@ARGREL_ATLEASTONE") end

"""
    @ARGREL_DEPENDS lhs rhs [help="..."]

Declare a dependency relation between two option-style relation expressions.

Behavior:
- Enforces: if `lhs` is satisfied, then `rhs` must also be satisfied.
- Relation checks are evaluated after parsing, using provided-argument tracking rather than final runtime value equality.
- For regular options and flags, an argument is considered present when it was explicitly provided.
- For count arguments (`@ARG_COUNT`), presence means the observed count is greater than zero.
- If the dependency is violated, parsing fails with a default message, or with the custom `help="..."` message when provided.

Supported relation expression forms:
- `a`
- `all(a, b, c)`
- `any(a, b, c)`
- `not(a)`
- nested forms such as `not(any(a, b))` or `all(a, not(b))` are accepted as long as they follow the supported grammar

Constraints:
- Requires exactly two relation expressions.
- All referenced names must refer to previously declared arguments in the same command scope.
- Only option-style arguments are allowed; positional arguments are rejected.
- `all(...)` and `any(...)` require at least one member.
- Duplicate names inside a single `all(...)` or `any(...)` expression are rejected.
- Accepts at most one `help="..."` keyword, and the help text must be a String literal.
- Not callable at runtime; this macro is only valid inside `@CMD_MAIN` or `@CMD_SUB` blocks.

Examples:
```julia
@CMD_MAIN MyCLI begin
    @ARG_FLAG auth "--auth"
    @ARG_FLAG token "--token"
    @ARG_FLAG user "--user"

    @ARGREL_DEPENDS auth any(token, user)
end
```

```julia
@CMD_MAIN MyCLI begin
    @ARG_FLAG remote "--remote"
    @ARG_FLAG host "--host"
    @ARG_FLAG port "--port"

    @ARGREL_DEPENDS remote all(host, port) help="--remote requires both --host and --port"
end
```
"""
macro ARGREL_DEPENDS(args...) _placeholder_macro_error("@ARGREL_DEPENDS") end

"""
    @ARGREL_CONFLICTS lhs rhs [help="..."]

Declare a conflict relation between two option-style relation expressions.

Behavior:
- Enforces: `lhs` and `rhs` must not both be satisfied at the same time.
- Relation checks are evaluated after parsing, using provided-argument tracking rather than final runtime value equality.
- For regular options and flags, an argument is considered present when it was explicitly provided.
- For count arguments (`@ARG_COUNT`), presence means the observed count is greater than zero.
- If the conflict is violated, parsing fails with a default message, or with the custom `help="..."` message when provided.

Supported relation expression forms:
- `a`
- `all(a, b, c)`
- `any(a, b, c)`
- `not(a)`
- nested forms such as `not(any(a, b))` are accepted

Constraints:
- Requires exactly two relation expressions.
- All referenced names must refer to previously declared arguments in the same command scope.
- Only option-style arguments are allowed; positional arguments are rejected.
- `all(...)` and `any(...)` require at least one member.
- Duplicate names inside a single `all(...)` or `any(...)` expression are rejected.
- Accepts at most one `help="..."` keyword, and the help text must be a String literal.
- Not callable at runtime; this macro is only valid inside `@CMD_MAIN` or `@CMD_SUB` blocks.

Examples:
```julia
@CMD_MAIN MyCLI begin
    @ARG_FLAG stdin "--stdin"
    @ARG_FLAG file "--file"
    @ARG_FLAG url "--url"

    @ARGREL_CONFLICTS stdin any(file, url)
end
```

```julia
@CMD_MAIN MyCLI begin
    @ARG_FLAG json "--json"
    @ARG_FLAG yaml "--yaml"

    @ARGREL_CONFLICTS json yaml help="Choose either --json or --yaml, not both"
end
```
"""
macro ARGREL_CONFLICTS(args...) _placeholder_macro_error("@ARGREL_CONFLICTS") end

"""
    @ARGREL_ONLYONE a b c ... [help="..."]

Declare a cardinality constraint requiring exactly one of a set of option-style arguments.

Behavior:
- Enforces that exactly one listed argument is considered present.
- Presence is based on parse-time provided tracking, not on final runtime value equality.
- For count arguments (`@ARG_COUNT`), an argument is considered present when its observed count is greater than zero.
- If zero or more than one listed argument is present, parsing fails with a default message, or with the custom `help="..."` message when provided.

Constraints:
- Requires at least one argument name.
- All names must refer to previously declared arguments in the same command scope.
- Only option-style arguments are allowed; positional arguments are rejected.
- Duplicate names are rejected.
- Accepts at most one `help="..."` keyword, and the help text must be a String literal.
- Although one name is technically accepted, this relation is typically meaningful only with two or more names.
- Not callable at runtime; this macro is only valid inside `@CMD_MAIN` or `@CMD_SUB` blocks.

Example:
```julia
@CMD_MAIN MyCLI begin
    @ARG_FLAG hex "--hex"
    @ARG_FLAG base64 "--base64"
    @ARG_FLAG raw "--raw"

    @ARGREL_ONLYONE hex base64 raw
end
```
"""
macro ARGREL_ONLYONE(args...) _placeholder_macro_error("@ARGREL_ONLYONE") end

"""
    @ARGREL_ALLORNONE a b c ... [help="..."]

Declare a cardinality constraint requiring either full presence or full absence of a set of option-style arguments.

Behavior:
- Enforces that either all listed arguments are present, or none of them is present.
- Presence is based on parse-time provided tracking, not on final runtime value equality.
- For count arguments (`@ARG_COUNT`), an argument is considered present when its observed count is greater than zero.
- If only a subset of the listed arguments is present, parsing fails with a default message, or with the custom `help="..."` message when provided.

Constraints:
- Requires at least one argument name.
- All names must refer to previously declared arguments in the same command scope.
- Only option-style arguments are allowed; positional arguments are rejected.
- Duplicate names are rejected.
- Accepts at most one `help="..."` keyword, and the help text must be a String literal.
- Although one name is technically accepted, this relation is typically meaningful only with two or more names.
- Not callable at runtime; this macro is only valid inside `@CMD_MAIN` or `@CMD_SUB` blocks.

Example:
```julia
@CMD_MAIN MyCLI begin
    @ARG_OPT String host "--host"
    @ARG_OPT Int port "--port"

    @ARGREL_ALLORNONE host port
end
```
"""
macro ARGREL_ALLORNONE(args...) _placeholder_macro_error("@ARGREL_ALLORNONE") end

"""
    @ARG_TEST name... fn [msg]

Declare post-parse validation for one or more argument values.

Behavior:
- Evaluates after parsing and type conversion.
- One or more argument names must be provided before the validator function.
- For each referenced argument:
  - If the value is `nothing`, validation is skipped (treated as pass).
  - Otherwise, requires `fn(value) == true`.
- On failure, parsing raises `ArgParseError`.
- Failure text always appends argument context: `Invalid arg: <name> (...)`.
- If `msg` is provided, it must be a string literal and is used as the custom prefix.

Constraints:
- Each `name` must refer to an already declared argument.
- At least one argument name is required.
- `fn` is required.
- Optional `msg` must be a string literal.
- At most one custom message is allowed.
- Duplicate names in one invocation are rejected.
- Not callable at runtime (placeholder macro outside DSL expansion).

---

## Built-in validator helpers

`@ARG_TEST` works well with RunicCLI's built-ins:

For example: (See `RunicCLIRuntime` for all available validators)

- Numeric
    - [`V_num_min(minv)`](@ref)
    - [`V_num_max(maxv)`](@ref)
    - [`V_num_range(lo, hi; closed=true)`](@ref)

- Membership
    - [`V_any_oneof(xs)`](@ref)
    - [`V_any_include(xs)`](@ref)
    - [`V_any_exclude(xs)`](@ref)

- String / pattern
    - [`V_str_length(; min=nothing, max=nothing, eq=nothing)`](@ref)
    - [`V_str_prefix(prefix)`](@ref)
    - [`V_str_suffix(suffix)`](@ref)
    - [`V_str_regex(re::Regex)`](@ref)

- Path
    - [`V_path_exists()`](@ref)
    - [`V_path_isfile()`](@ref)
    - [`V_path_isdir()`](@ref)
    - [`V_path_readable()`](@ref)
    - [`V_path_writable()`](@ref)

- Composition
    - [`V_AND(f1, f2, ...)`](@ref)
    - [`V_OR(f1, f2, ...)`](@ref)

---

## Examples

Built-in composition:

```julia
@ARG_TEST port V_AND(V_num_min(1), V_num_max(65535)) "port must be in 1..65535"
@ARG_TEST mode V_any_oneof(["fast", "safe", "debug"]) "invalid mode"
@ARG_TEST input V_AND(V_path_exists(), V_path_isfile(), V_path_readable()) "input must be a readable file"
```

Multi-argument validation in one declaration:

```julia
@ARG_TEST host backup_host x -> !isempty(strip(x)) "host must not be blank"
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

---

## Built-in validator helpers

For example: (See `RunicCLIRuntime` for all available validators)

- Numeric
    - [`V_num_min(minv)`](@ref)
    - [`V_num_max(maxv)`](@ref)
    - [`V_num_range(lo, hi; closed=true)`](@ref)

- Membership
    - [`V_any_oneof(xs)`](@ref)
    - [`V_any_include(xs)`](@ref)
    - [`V_any_exclude(xs)`](@ref)

- String / pattern
    - [`V_str_length(; min=nothing, max=nothing, eq=nothing)`](@ref)
    - [`V_str_prefix(prefix)`](@ref)
    - [`V_str_suffix(suffix)`](@ref)
    - [`V_str_regex(re::Regex)`](@ref)

- Path
    - [`V_path_exists()`](@ref)
    - [`V_path_isfile()`](@ref)
    - [`V_path_isdir()`](@ref)
    - [`V_path_readable()`](@ref)
    - [`V_path_writable()`](@ref)

- Composition
    - [`V_AND(f1, f2, ...)`](@ref)
    - [`V_OR(f1, f2, ...)`](@ref)

---

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


"""
    @ARG_GROUP "title" arg1 arg2 ...

Declare a help-display group for arguments.

`@ARG_GROUP` does not change parsing, typing, sourcing, or validation semantics. It only affects how
arguments are organized in generated help output by assigning the listed arguments to a named section.

Behavior:
- Creates a titled argument group in help rendering.
- Each listed argument becomes a member of that group.
- Group membership is metadata only; it does not imply mutual exclusion, requirement, or validation.
- Both option-style and positional arguments may be grouped.
- Arguments that are not assigned to any explicit group remain in the default help section.

Constraints:
- The first argument must be a non-empty String literal used as the group title.
- At least one argument name must be provided after the title.
- Each argument name must be a symbol identifier.
- All referenced arguments must already be declared in the same command or subcommand block.
- An argument may belong to at most one `@ARG_GROUP` within the same block.
- Duplicate argument names inside the same `@ARG_GROUP` are rejected.
- Not callable at runtime (placeholder macro outside DSL expansion).

Examples:
```julia
@CMD_MAIN MyCLI begin
    @ARG_REQ String host "--host" help="Server host"
    @ARG_OPT Int port "--port" default=8080 help="Server port"
    @ARG_FLAG verbose "-v" "--verbose" help="Verbose logging"
    @POS_OPT String logfile help="Optional log file"

    @ARG_GROUP "Server Options" host port
    @ARG_GROUP "Runtime" verbose logfile
end
```

Inside a subcommand:
```julia
@CMD_MAIN MyCLI begin
    @CMD_SUB "serve" begin
        @ARG_REQ String host "--host"
        @ARG_OPT Int port "--port" default=8080
        @ARG_FLAG reload "--reload"

        @ARG_GROUP "Network" host port
        @ARG_GROUP "Development" reload
    end
end
```

See also:
[`@CMD_MAIN`](@ref), [`render_help`](@ref)
"""
macro ARG_GROUP(args...) _placeholder_macro_error("@ARG_GROUP") end
