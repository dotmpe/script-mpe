#!/usr/bin/env bash

[[ ${US_ENV_PARTS:+set} ]] &&
[[ ${US_ENV_INIT:+set} ]] &&
eval "$US_ENV_INIT" &&
unset US_ENV_INIT || {
  >&2 echo "Expected User-Script profile env, loading"
  #. "profile,host,us.sh"
  /usr/share/uc/us-host-profile.sh
}

Games.DOSBox.usercmd ()
{
  : "${ANNEX_DIR:=/srv/annex-local/${ANNEX_ID:=archive-1}}"

  case "${1}" in
  ( start:* )
      local game_status
      us_part --hooks:init,start games-dosbox &&
      Games.DOSBox.start-game ${1#start:}
      game_status=$?
      us_part --hooks:stop games-dosbox && return ${game_status}
    ;;

  ( --info|info )
      us_part --hooks:init games-dosbox &&
      if [[ ${2:+set} ]]; then
        path=${games_dosbox_dirmap[$2]-}
        conf=${UCONF:?}/etc/dosbox/${path,,}.conf
        echo "Path: ${path}"
        echo "Archive-Path: ${games_dosbox_zipdirmap[$2]-}"
        echo "Executable: ${games_dosbox_execmap[$2]-}"
        if [[ ${games_dosbox_notes[$2]:+set} ]]; then
          echo "Game notes:"
          <<< "${games_dosbox_notes[$2]}" str_prefix '  '
        fi
        if [[ -f $path ]]; then
          echo "DOSBox config missing"
        else
          echo "DOSBox config:"
          < "$conf" str_prefix '  '
        fi
      else
        printf.lines.array-keys games_dosbox_dirmap
      fi
    ;;

  ( --notes|notes )
      us_part --hooks:init games-dosbox &&
      if [[ ${2:+set} ]]; then
        :
      else
        printf.lines.array-keys games_dosbox_notes
      fi
    ;;

  ( --help|help|-[h'?'] )
      echo "Usage:
    dosgames.sh start:<name>
    dosgames.sh ( start|stop|init|deinit|clean|status ) # Run hooks
    dosgames.sh [--]info [<name>]                       # Show names
    dosgames.sh [--]notes [<name>]                      # Show notes
"
    ;;

  ( start|stop|init|deinit|clean|status|\
    init,start|init,stop )
      us_part --hooks:$1 games-dosbox &&
      >&2 echo "DOSGames $* OK"
    ;;
   * ) return ${_E_nsc:?}
  esac
}

(($#)) || set -- status

Games.DOSBox.usercmd "$@" || failerr "E$? running user command for $*" || exit
#
