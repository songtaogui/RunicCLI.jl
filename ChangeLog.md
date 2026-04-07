# V0.2.2
- support `\n` and `"""..."""` in `help=` kwarg of macros, and `@CMD_DESC, @CMD_EPILOG, @CMD_USAGE`.
- auto generate `-h, --help` and `-V, --version` if available.
- auto adjust `wrap_width` based on terminal width if `wrap_with=0 or nothing`
- Redesign Validators, now add many usefull validators and docstring.