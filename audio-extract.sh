set -euo pipefail

test $# -gt 0 || stderr_exit 2 "" "Need one filename argument"
test $# -ge 1 && {
  test -e "$1" || {
    stderr_exit 2 "" "Find basename for '$1'"
  }
}

test -z "${cext:=${2:-}}" || convert=true

$LOG notice : "Inputs: ..."
file -s "${1%%.*}".* ||
  stderr_exit $? "" "Unexpected E$?"

fn_music=
! "${convert:-false}" && {
  fn_a=${1%.webm}.audio.webm
  test ! -e "$fn_a" || {
    stderr_exit 3 "" "Audio container already exists"
  }
} || {
  test -e ~/Downloads -a -e ~/Music -a -e ~/Videos ||
    stderr_exit 3 "" "Unexpected home"
  fn_a=${1%.webm}.$cext
  str_wordmatch Music ${fn_a//\// } && {
    : "${fn_a:?}"
    : "${_//Music\/}"
    : "${_//Downloads/Music\/Media\/Audio}"
    : "${_//Videos/Music\/Media\/Audio}"
    fn_music=$_
    test -e "$(dirname "$fn_music")" ||
      stderr_exit 3 "" "Expected dest dir"
    # XXX: would like to handle alt basedirs
    #fnmatch "*/*" "$_" ||
  }
  test -e "${fn_music:-${fn_a:?}}" ||
    stderr echo "Converting to $_..."
}

test -e "${fn_music:-${fn_a:?}}" ||
ffmpeg \
  -i "$1" \
  -vn \
  "$_"

! "${convert:-false}" || {
  test -e "${fn_music:-${fn_a:?}}" ||
  test "$1" = "$_" ||
  mv -v "$fn_a" "$_"
}

$LOG notice : "Results: ..."
file -s "${fn_music:-${fn_a:?}}" ||
  stderr_exit $? "" "Unexpected E$? at file $_"
