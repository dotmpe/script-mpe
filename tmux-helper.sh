#!/usr/bin/env bash

update-environment ()
{
  local cur_val
  cur_val=$(tmux show-opt -g update-environment)
  for var in "${@:?}"
  do
    regex="\ $var\>"
    [[ "$cur_val" =~ $regex ]] && continue
    tmux set -ag update-environment "$var"
  done
}

show-preserve-environment ()
{
  tmux show -g update-environment
}

check-environment ()
{
  tmux show-env | while read -r setting
    do
        varn=${setting//=*}
        fnmatch "-*" "$varn" && {
            continue
        }
        varc="${!varn:-}"
        test "$setting" = "$varn=$varc" || {
            ${list_vars:-false} && echo "$varn"
            ${list_env:-false} && echo "$varn=\"$varc\""
            echo "Tmux session has changed: '$setting', local: '$varc'" >&2
        }
    done
}

list-update-env ()
{
  list_env=true check-environment
}

test -n "${user_script_loaded:-}" || {
  . "${US_BIN:="$HOME/bin"}"/user-script.sh &&
        user_script_shell_env
}


! script_isrunning "tmux-helper" .sh || {
  base=tmux-helper
  script_baseext=.sh
  script_cmdals=
  script_defcmd=
  eval "set -- $(user_script_defarg "$@")"
}

script_entry "tmux-helper" "$@"
#
