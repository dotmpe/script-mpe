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
  case "${1}" in
  ( start:* )
      local game_status
      us_part --hooks:init,start games-dosbox &&
      Games.DOSBox.start-game ${1#start:}
      game_status=$?
      us_part --hooks:stop games-dosbox && return ${game_status}
    ;;

  ( start|stop|update|init|deinit|clean|status|\
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
