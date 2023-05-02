#!/usr/bin/env bash

update_environment ()
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

show_preserve_environment ()
{
  tmux show -g update-environment
}

check_environment ()
{
  tmux show-env | while read -r setting
    do
        varn=${setting//=*}
        fnmatch "-*" "$varn" && {
          #declare -p "${varn:1}" >/dev/null 2>&1 && {
          #  echo "tmux env sync: unset? $_=${!_}" >&2
          #  #unset ${_:?}
          #}
          continue
        }
        varc="${!varn:-}"
        test "$setting" = "$varn=$varc" || {
          ${list_vars:-false} && echo "$varn"
          ${list_env:-false} && echo "$varn=\"${setting/*=}\""
          echo "Tmux session changed: '$setting', local was: '$varc'" >&2
        }
    done
}

list_update_env ()
{
  list_env=true check_environment
}

# Return Id for window
window_spec ()
{
  test -n "${WINDOWID:-}" && {
      case "$XDG_SESSION_TYPE" in
          ( x11 )
                  case "$XDG_SESSION_DESKTOP" in
                      ( i3 ) echo "i3:$(i3-msg -t get_workspaces|jq '.[]|select(.focused==true).num')" ;;
                      ( * ) : "$(xprop -id $WINDOWID -notype _NET_WM_DESKTOP)"
                            echo "${_/* = /}"
                          ;;
                  esac
              ;;
          ( tty )
                  test -n "${SSH_TTY:-}" &&
                  echo "ssh:${SSH_TTY//*\/}" || {
                      : "$(tty)"
                      echo "tty:${_//*\/}"
                  }
              ;;
          ( * ) echo "$XDG_SESSION_TYPE:$WINDOWID"
      esac
  } || {
      echo "(?)"
  }
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
