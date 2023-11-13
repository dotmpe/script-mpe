set -euo pipefail

test $# -gt 0 || stderr error_handler "Need one filename argument" 2
test $# -ge 1 && {
  test -e "$1" || {
    stderr error_handler "Find basename for '$1'" 2
  }
}

test -z "${cext:=${2:-}}" || convert=true

$LOG notice : "Inputs: ..."
file -s "${1%%.*}".* ||
  stderr error_handler "Unexpected E$?" $?

fn_music=
! "${convert:-false}" && {
  fn_a=${1%.webm}.audio.webm
  test ! -e "$fn_a" || {
    stderr error_handler "Audio container already exists" 3
  }
} || {
  test -e ~/Downloads -a -e ~/Music -a -e ~/Videos ||
    stderr error_handler "Unexpected home" 3
  fn_a=${1%.webm}.$cext
  str_wordmatch Music ${fn_a//\// } && {
    : "${fn_a:?}"
    : "${_//Music\/}"
    : "${_//Downloads/Music\/Media\/Audio}"
    : "${_//Videos/Music\/Media\/Audio}"
    fn_music=$_
    test -e "$(dirname "$fn_music")" ||
      stderr error_handler "Expected dest dir" 3
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
  stderr error_handler "Unexpected E$? at file $_" $?
