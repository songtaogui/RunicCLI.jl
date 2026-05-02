# V0.2.2
- support `\n` and `"""..."""` in `help=` kwarg of macros, and `@CMD_DESC, @CMD_EPILOG, @CMD_USAGE`.
- auto generate `-h, --help` and `-V, --version` if available.
- auto adjust `wrap_width` based on terminal width if `wrap_with=0 or nothing`
- Redesign Validators, now add many usefull validators and docstring.

# V0.2.3
- OracliRuntime: add additional path/file/dir validators and tests.

# V0.3.0
- Add `ValidatorSpec` struct, for better validator msg.
- `V_*` built-in validators now return ValidatorSpec.
- `V_AND, V_OR, V_NOT` support both fn and ValidatorSpec.
- `vfun=` now can accept 3 ways:
    1. ValidatorSpec;
    2. function (will turn into ValidatorSpec with empty vmsg);
    3. Pair(msg, fn): `"msg" => fn`;
- `vmsg=` will overwrite built-in msgs.

# V0.3.1
- add `name` attribute for ValidatorSpec
- update name of built-in validators
- update `V_AND, V_OR, V_NOT` to support name construction

# V0.4.1

## 1. Re-design the arg relationship marcos:

Rename and expand:

- `@ARG_REQUIRES` -> `@ARGREL_DEPENDS`
- `@ARG_CONFLICTS` -> `@ARGREL_CONFLICTS`
- `@GROUP_EXCL` -> `@ARGREL_ATMOSTONE`
- `@GROUP_INCL` -> `@ARGREL_ATLEASTONE`
- add new marcos: `@ARGREL_ONLYONE` and `@ARGREL_ALLORNONE`

Add `help=""` kwargs to control msg.

## 2. `@CMD_AUTOHELP`

add `@CMD_AUTOHELP` for `@CMD_MAIN` and `@CMD_SUB` to turn on auto help msg if no args were provided.

# V1.0.0

## 1. rename all inner-functions

No longer use `_` as the prefix of inner functions.

## 2. Rename module: Oracli.jl

