### Use playerctl to talk with MPRIS services

# A few useful keys that do not show up in the metadata listing:
#
# - status Playing/Paused
# - position int
# - volume float 0-1
# - shuffle true/false
# - loop None/Playlist/Track
# - playerInstance and playerName


ctx_playerctl_lib__load ()
{
  : "${MPRIS_MEDIALOG_KEYS:="playerInstance status position mpris:length xesam:url mpris:trackid artist album track title"}"
}

at_Playerctl__medialog ()
{
  local fmt keys=${1:-${MPRIS_MEDIALOG_KEYS:?}}
  fmt="$(echo $(for a in $keys; do echo "{{$a}}"; done) | tr ' ' '\t')"
  at_Playerctl__metadata "$(date --iso=ns)"$'\t'"$hostname"$'\t'"$fmt"
}

at_Playerctl__metadata () # ~ <Format> [<Players...>]
{
  local fmt="${1:?}" ; shift
  test $# -gt 0 || set -- $(at_Playerctl__players_playing)

  while test $# -gt 0
  do
    playerctl -p "$1" -f "$fmt" metadata
    shift
  done
}

at_Playerctl__players ()
{
  local fmt=$(printf "{{%s}}\t{{%s}}\t{{%s}}\n" "playerName" "playerInstance" "status")
  playerctl -a -f "$fmt" metadata
}

at_Playerctl__players_playing () # ~
{
  at_Playerctl__players_status "Playing"
}

at_Playerctl__players_status () # ~
{
  at_Playerctl__players | awk '/'$'\t'"${1:-".*"}"'$/{ print $2 }'
}

at_Playerctl__playing_now () # ~
{
  local ts=$(date +'%s')
  at_Playerctl__${1:-tsv} \
        'playerName status mpris:trackid mpris:length position title' |
    grep $'\t''Playing'$'\t' | sed 's/^/'"$ts"' /'
}

at_Playerctl__reportlines ()
{
  echo "$format log medialog @Playerctl @MPRIS -- at_Playerctl__medialog"
}

# Output tab-separated lines and columns header line
at_Playerctl__tsv () # ~ [<Keys>] [<Players...>]
{
  local fmt keys=${1:-${MPRIS_MEDIALOG_KEYS:?}}
  test $# -eq 0 || shift

  fmt="$(echo $(for a in $keys; do echo "{{$a}}"; done) | tr ' ' '\t')"
  echo "# $(echo $(for a in $keys; do echo "$a"; done))"
  at_Playerctl__metadata "$fmt" "$@"
}

at_Playerctl__txt ()
{
  local fmt keys=${1:-${MPRIS_MEDIALOG_KEYS:?}}
  test $# -eq 0 || shift

  fmt="$(for a in $keys; do echo "$a: {{$a}}"; done)"
  at_Playerctl__metadata "$fmt" "$@"
}

#
