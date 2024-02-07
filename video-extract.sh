cmd_usage="video-extract <File> <Start-time> <End-Time> [<Title> [<Comment>]]"
cmd_descr="Create clip (and convert) from given video file"

set -e

test 3 -le $# -o 6 -ge $# && {

  out=${4:-out.mp4}
  # Remove all metadata (map global, stream, chapter and program from -1)
  # set new title to filename (if left empty)
  new_title=${5:-${out##*/}}
  # (empty value removes tag)
  new_comment=${6-}
  ffmpeg \
    -i "${1:?}" \
    -ss "${2:?}" -to "${3:?}" \
    -map_metadata -1:g \
    -map_metadata -1:s \
    -map_metadata -1:c \
    -map_metadata -1:p \
    -metadata title="${new_title:?}" \
    -metadata comment="${new_comment:?}" \
    "${out:?}"
  exit $?
} || {
  { echo Usage: $cmd_usage
    echo
    echo "$cmd_descr"
  } >&2
  exit 2
}
