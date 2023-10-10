# video-extract <File> <Start-time> <End-Time>
set -e
ffmpeg \
  -i "${1:?}" \
  -ss "${2:?}" -to "${3:?}" \
  out.mp4
