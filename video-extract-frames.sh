: "$(basename "${1:?}" .mp4)"
frames=$(( ${3:?} - ${2:?} ))

set -e

#rm out*.mp4
rm out*.webm || true

# XXX: see video-extract, going by frames (like here) is too problematic
#ffmpeg \
#  -i "$1" \
#  -vn \
#  -af "aselect=between(n\,$2\,$3),setpts=PTS-STARTPTS" \
#  out-audio.webm

ffmpeg \
  -i "$1" \
  -an \
  -vf "select=between(n\,$2\,$3),setpts=PTS-STARTPTS" \
  out-vid.webm
