function _all_flags(def::CliDef)
    fs = String[]
    for a in def.args
        append!(fs, a.flags)
    end
    for s in def.subcommands
        for a in s.args
            append!(fs, a.flags)
        end
    end
    unique(fs)
end

"""
    generate_completion(def::CliDef; shell::Symbol=:bash, prog::String=...) -> String

Generate a shell-completion script snippet from a [`CliDef`](@ref).

Arguments:
- `def`: CLI definition.
- `shell`: target shell symbol (`:bash`, `:zsh`, or `:fish`).
- `prog`: command name used in completion entries (defaults to `def.cmd_name`, fallback `"cmd"`).

Behavior:
- Collects flags from main args and subcommand args.
- Collects subcommand names.
- Includes standard `-h`, `--help`, `-V`, `--version`.

Current support status:
- `:fish`
- `:bash`
- `:zsh`
- Unknown `shell` throws `ArgumentError`.

This helper is intended for packaging/install-time completion generation.
"""
function generate_completion(def::CliDef; shell::Symbol=:bash, prog::String=isempty(def.cmd_name) ? "cmd" : def.cmd_name)::String
    flags = join(_all_flags(def), " ")
    subs = join([s.name for s in def.subcommands], " ")

    if shell == :bash
        return """
_$(prog)_complete() {
  local cur prev words cword
  _init_completion || return
  local opts="$(flags) $(subs) -h --help -V --version"
  COMPREPLY=( \$(compgen -W "\$opts" -- "\$cur") )
}
complete -F _$(prog)_complete $(prog)
"""
    elseif shell == :zsh
        return """
#compdef $(prog)
_arguments '*: :->args'
if [[ \$state == args ]]; then
  _values 'args' $(flags) $(subs) -h --help -V --version
fi
"""
    elseif shell == :fish
        lines = String[]
        for x in split("$flags $subs -h --help -V --version")
            if startswith(x, "--")
                push!(lines, "complete -c $prog -l $(x[3:end])")
            elseif startswith(x, "-")
                push!(lines, "complete -c $prog -s $(x[2:end])")
            else
                push!(lines, "complete -c $prog -a '$x'")
            end
        end
        return join(lines, "\n") * "\n"
    else
        throw(ArgumentError("Unsupported shell: $(shell)"))
    end
end
