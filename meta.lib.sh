
filetype()
{
  test -e "$1" || error "expected existing path <$1>" 1

  case "$uname" in

    Darwin )
      file -b --mime-type "$1"
      ;;

    * )
      error "No filetype for $uname" 1
      ;;

  esac
}


mediadurationms()
{
  echo "General;%Duration%" > /tmp/template.txt
  mediainfo --Output=file:///tmp/template.txt "$1"
}

mediaresolution()
{
  echo "Video;%Width%x%Height%" > /tmp/template.txt
  mediainfo --Output=file:///tmp/template.txt "$1"
}

mediapixelaspectratio()
{
  echo "Video;%PixelAspectRatio/String%" > /tmp/template.txt
  mediainfo --Output=file:///tmp/template.txt "$1"
}

mediadisplayaspectratio()
{
  echo "Video;%DisplayAspectRatio/String%" > /tmp/template.txt
  mediainfo --Output=file:///tmp/template.txt "$1"
}


# General;%CompleteNae% * %FileSize/String3% * %Duration/String%
# Video; |Video: %Width%x%Height% * %DisplayAspectRatio/String% * %Format%
# %Format_Profile%
# Audio; |Audio: %Language/String% * %Channel(s)% CH * %Codec/String%
# Text; |Sub: %Language/String% * %Codec%
# File_End;\n



