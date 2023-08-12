: "$(basename "${1:?}" .mp4)"
 ffmpeg -i "$1" \
   -r 12 \
   -vf "scale=512:-1,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
   "$_.gif"
