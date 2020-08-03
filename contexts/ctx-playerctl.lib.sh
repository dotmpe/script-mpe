
at_Playerctl__tab ()
{
  local fmt
  test -n "$*" || set -- playerName position "duration(position)" "duration(mpris:length)" status volume album artist title mpris:track mpris:trackid
  fmt="$(for a in $@; do echo "{{$a}}"; done | tr -s '\n ' '\t')"
  echo "# $(echo $(for a in $@; do echo "$a"; done) | tr -s '\n ' '\t' )"
  playerctl -a -f "$fmt" status -f
}
