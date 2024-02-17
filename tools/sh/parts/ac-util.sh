
ac_spec () # ~ <Cmd-name> # Print auto-complete declaration for command or return nonzero status
{
  complete -p "${1:?}" 2>/dev/null
}

# Helper to set any sort of auto-completion for given command.
# (alias, builtin, command, keyword, function or variable names)
ac_sym () # ~ <Cmd>
{
  complete -a -b -c -k -A function -A variable "$@"
}

# Helper that uses compgen to filter array by word prefix, outputs each match
# separate line.
uc_compgen_from_array () # ~ [<Complete-word>] [<Word-arr>]
{
  #shellcheck disable=2178 # Var is name-ref to array
  declare -n arr=${2:?}
  compgen -W "${arr[*]@Q}" -- "${1-}"
}

# AC handler using us-exec-commands list
us_complete_commands () # ~ <Command-name> <Complete-word> <Previous-word>
{
  sh_build_array user_shell_commands "$PATH" us_exec_commands || return
  # Make sure commands are cached (in global array) before entring into subshell
  #sh_arr_assert user_shell_commands us_exec_commands || return
  # Get completions from subshell and read into array
  sys_arr COMPREPLY uc_compgen_from_array "${2-}" user_shell_commands
}

# List only executable names found on PATH. Normal `compgen -c` lists other
# commands (function, alias, builtin and keyword names) as well, this wraps
# compgen and removes those. Alternatively, commands can be preselected and
# provided as array, except a nonzero complete-word then returns E:GAE status.
us_exec_commands () # ~ [<Complete-word>] [<Cmd-arr->]
{
  test -z "${2-}" && {
    declare arr=()
    if_ok "$(compgen -c "${1-}")" &&
    <<< "$_" mapfile -t arr || return
  } || {
    test -z "${1:-}" || return ${_E_GAE:?}
    #shellcheck disable=2178 # Var is name-ref to array
    declare -n arr=${2:?}
  }
  for sym in "${arr[@]}"
    do
      case "$(type -t "$sym")" in
        alias | function | keyword | builtin ) continue
      esac
      echo "$sym"
    done
}

#
