
# Bash helper for ImageMagic particular gradient image generation


# Generates a multi-color gradient at 90-degree angles.
# 180 degrees essential means gradient goes from top to bottom.
im_cubic_gradient () # ~ <Size> <Rotation> <Image> <Swatches...>
{
  convert \
    -size ${1:-600x600} gradient: -rotate ${2:-180} \
    -interpolate Bicubic \( +size "${@:4}" +append \) \
    -clut ${3:-gradient.jpg}
}


# XXX: color swatches for IM gradients

chauvet_1_1=ff8700
chauvet_1_2=ffd700
chauvet_1_3=ffffd7

chauvet_2_1=87afff
chauvet_2_2=8787ff
chauvet_2_3=8787af

chauvet_3_1=af5f00
chauvet_3_2=d78700
chauvet_3_3=eedc82
chauvet_3_4=87af00

chauvet_day_dark=xc:black\ xc:\#$chauvet_2_1\ xc:\#$chauvet_2_2\ xc:\#$chauvet_3_4\ xc:black
chauvet_day_light=xc:white\ xc:\#$chauvet_2_1\ xc:\#$chauvet_2_2\ xc:\#$chauvet_3_4\ xc:white
chauvet_evening_pasture=xc:black\ xc:\#$chauvet_3_1\ xc:\#$chauvet_3_2\ xc:\#$chauvet_3_3\ xc:\#$chauvet_3_4\ xc:black
chauvet_dystopic_glow=xc:\#$chauvet_1_3\ xc:\#$chauvet_1_2\ xc:\#$chauvet_1_1\ xc:black

chauvet_day_blue="xc:black xc:#$chauvet_2_1 xc:#$chauvet_2_2 xc:#$chauvet_2_3"
chauvet_day_green="xc:black xc:#$chauvet_3_4 xc:#$chauvet_1_3"
chauvet_dark_green_mono="xc:black xc:#$chauvet_3_4"
chauvet_dark_orange_mono=xc:\#$chauvet_1_1\ xc:black


# Generate and set one or more gradient backgrounds, each monitor can have its
# own rotation. The (multi-swatch) gradient palette has to be prepared as env
# variable.
user_background_gradient () # ~ <Size> <Palette-var> <Rotation> <Rotation-2...>
{
  size=${1:?}
  : "${2//[^A-Za-z0-9_]/_}"
  im_gradient_palette=${!_:?}
  shift 2
  test $# -gt 0 || set -- 180
  imgbase=/tmp/bg
  imgcnt=0
  declare -a images=()
  while test $# -gt 0
  do
    imgcnt=$(( imgcnt + 1 ))
    im_cubic_gradient "$size" "$1" "$imgbase-$imgcnt.jpg" $im_gradient_palette
    images+=( "$imgbase-$imgcnt.jpg" )
    shift
  done
  eval feh $(printf -- ' --bg-scale "%s" ' "${images[@]}")
}

#
