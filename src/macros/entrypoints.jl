"""
    @CMD_MAIN TypeName begin
        ...
    end

Define a complete Oracli command schema and generate the parser/dispatch implementation for `TypeName`.

`@CMD_MAIN` is the top-level DSL entrypoint. It validates the command declaration at macro-expansion time and
builds a typed command result with support for options, positionals, validators, argument relations, help metadata,
version handling, and subcommands.

---

## Block contract

- The second argument **must** be a `begin ... end` block.
- The first argument **must** be a plain type-name `Symbol` (dotted names are not supported).
- Inside the block, only Oracli DSL macros are allowed (non-macro statements are rejected).

---

## Command-level metadata macros (main block)

Each may appear at most once:

- `@CMD_USAGE "..."` — custom usage text
- `@CMD_DESC "..."` — description text
- `@CMD_EPILOG "..."` — trailing help text
- `@CMD_VERSION "..."` — version text
- `@ALLOW_EXTRA` — allow unconsumed extra arguments
- `@CMD_AUTOHELP` — enable automatic help behavior for this command

---

## Argument declaration macros

### Option-style

- `@ARG_REQ T name flags... [help="..."] [help_name="..."] [vfun=...] [vmsg="..."]`
- `@ARG_OPT T name flags... [help="..."] [help_name="..."] [env="..."] [default=...] [fallback=other] [vfun=...] [vmsg="..."]`
- `@ARG_FLAG name flags... [help="..."] [help_name="..."] [vfun=...] [vmsg="..."]`
- `@ARG_COUNT name flags... [help="..."] [help_name="..."] [vfun=...] [vmsg="..."]`
- `@ARG_MULTI T name flags... [help="..."] [help_name="..."] [vfun=...] [vmsg="..."]`

### Positional

- `@POS_REQ T name [help="..."] [help_name="..."] [vfun=...] [vmsg="..."]`
- `@POS_OPT T name [help="..."] [help_name="..."] [env="..."] [default=...] [fallback=other] [vfun=...] [vmsg="..."]`
- `@POS_REST T name [help="..."] [help_name="..."] [vfun=...] [vmsg="..."]`

Notes:

- `@POS_REST` can appear only once and must be last positional declaration.
- `vmsg` requires `vfun`.
- Inline `vfun` validation is scalar for single-value args and element-wise for streaming args (`@ARG_MULTI`, `@POS_REST`).

---

## Post-parse validator macros

### `@ARG_TEST`

```julia
@ARG_TEST arg1 [arg2 ...] vfun=... [vmsg="..."]
```

- Applies validator(s) after parsing.
- Supports one or more argument names.
- For optional scalar args, validation skips `nothing`.
- For streaming args (`@ARG_MULTI`, `@POS_REST`), validation is element-wise.
- Referenced arguments must be declared.

### `@ARG_STREAM`

```julia
@ARG_STREAM arg vfun=... [vmsg="..."]
```

- Applies element-wise post-parse validation.
- `arg` must be a streaming argument (`@ARG_MULTI` or `@POS_REST`).
- Only keyword arguments are accepted (`vfun`, `vmsg`).

---

## Argument relations

- `@ARGREL_DEPENDS lhs rhs [help="..."]`
- `@ARGREL_CONFLICTS lhs rhs [help="..."]`
- `@ARGREL_ATMOSTONE a b ... [help="..."]`
- `@ARGREL_ATLEASTONE a b ... [help="..."]`
- `@ARGREL_ONLYONE a b ... [help="..."]`
- `@ARGREL_ALLORNONE a b ... [help="..."]`

`lhs` / `rhs` relation expressions support:

- `a`
- `all(a,b,...)`
- `any(a,b,...)`
- `not(...)`

All referenced members must be declared, and relation members are validated for duplicates.

---

## Help grouping

```julia
@ARG_GROUP "Title" arg1 arg2 ...
```

- Defines display groups for help output.
- Title must be non-empty string.
- An argument may belong to at most one group per command block.

---

## Subcommands

Declare subcommands inside `@CMD_MAIN` using:

```julia
@CMD_SUB "name" begin ... end
@CMD_SUB "name" "description" begin ... end
```

Subcommand block rules mirror main command rules:

- DSL macros only
- supports command metadata (`@CMD_USAGE`, `@CMD_DESC`, `@CMD_EPILOG`, `@CMD_VERSION`, `@ALLOW_EXTRA`, `@CMD_AUTOHELP`)
- supports full argument/validation/relation/group declarations

Duplicate subcommand names are rejected.

---

## Validation and semantic checks performed at compile time

`@CMD_MAIN` performs strict checks, including:

- duplicate argument names
- duplicate flags across arguments
- invalid flag formats
- unknown referenced arguments
- invalid fallback targets
- fallback cycles
- duplicated metadata macros
- non-DSL nodes in DSL blocks
- malformed validator/relation/group syntax

Errors are raised as `ArgumentError` during macro expansion when possible.

---

## See also

[`@CMD_SUB`](@ref), [`@ARG_OPT`](@ref), [`@ARG_TEST`](@ref), [`@ARG_STREAM`](@ref),
[`@ARGREL_DEPENDS`](@ref), [`@ARG_GROUP`](@ref)
"""
macro CMD_MAIN(struct_name, block)
    return build_cmd_main_expr(struct_name, block)
end