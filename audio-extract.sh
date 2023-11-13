set -euo pipefail

test $# -gt 0 || stderr error_handler "Need one filename argument" 2
test $# -ge 1 && {
  test -e "$1" || {
    stderr error_handler "Find basename for '$1'" 2
  }
}

test -z "${cext:=${2:-}}" || convert=true

file -s "${1%%.*}".* ||
  stderr error_handler "Unexpected E$?" $?

! "${convert:-false}" && {
  fn_a=${1%.webm}.audio.webm
  test ! -e "$fn_a" || {
    stderr error_handler "Audio container already exists" 3
  }
} || {
  test -e ~/Downloads -a -e ~/Music -a -e ~/Videos ||
    stderr error_handler "Unexpected home" 3
  fn_a=${1%.webm}.$cext
  test -e "$fn_a" ||
    stderr echo "Converting to $fn_a..."
}

{ "${convert:-false}" && {
    str_wordmatch "${fn_a//\// }" Music && {
      : "${fn_a:?}"
      : "${_//Music\/}"
      : "${_//Downloads/Music\/Media\/Audio}"
      : "${_//Videos/Music\/Media\/Audio}"
      fn_music=$_
      test -e "$(dirname "$fn_music")" ||
        stderr error_handler "Expected dest dir" 3
      # XXX: would like to handle alt basedirs
      #fnmatch "*/*" "$_" ||
      fn_music=$_
    }
    test -e "$fn_a" -o -e "$fn_music"
  } || {
    test -e "$fn_a"
  }
} ||
ffmpeg \
  -i "$1" \
  -vn \
  "$fn_a"

! "${convert:-false}" || {
  test -e "$fn_music" || mv -v "$fn_a" "$_"
}
