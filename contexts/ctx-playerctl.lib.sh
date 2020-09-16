#!/usr/bin/env bash

at_Playerctl__tab () # [ Players... ]
{
    local fmt
    local keys="playerName position status volume album artist title track mpris:trackid"
    fmt="$(for a in $keys; do echo "{{$a}}"; done | tr -s '\n ' '\t')"
    echo "# $(echo $(for a in $keys; do echo "$a"; done) | tr -s '\n ' '\t' )"
    at_Playerctl__metadata "$fmt" "$@"
}

at_Playerctl__metadata () # Format Players....
{
    local fmt="$1" ; shift
    test -z "$*" && {
        playerctl -a -f "$fmt" metadata
    return $?
} ||
    while test $# -gt 0
    do
        playerctl -p "$1" -f "$fmt" metadata
        shift
    done
}

at_Playerctl__medialog ()
{
  at_Playerctl__metadata "$(date --iso=ns) $hostname {{ playerName }} {{ duration(position) }} {{ status }} {{ artist }} {{ album }} {{ title }}"
}

at_Playerctl__reportlines ()
{
  echo "log medialog @Playerctl @MPRIS -- at_Playerctl__medialog"
}

at_Playerctl__players ()
{
  local players="$(playerctl -l | tr -s '\n ' ' ')"
  for playerName in $( playerctl -a -f "{{ playerName }}" metadata )
  do
    printf "%s\t%s\n" "$playerName" "$(for player in $players;do
      fnmatch "$playerName*" "$player" || continue; echo "$player"; break;done)"
  done
}

at_Playerctl__playing_now () # State
{
  test $# -gt 0 || set -- Playing
  { test -n "$1" && {
      at_Playerctl__tab | grep Playing
  } || {
      at_Playerctl__tab
  }; } | {
      test -t 1 && column -s$'\t' -txc9 || cat -
  }
}

#
