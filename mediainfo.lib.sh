mediainfo_lib__load ()
{
    : "${mnfo_tpldir:=${RAM_TMPDIR:-${RAMDIR:-/tmp}}}"
}


mediainfo_durationms () # ~ <Media-File>
{
  echo "General;%Duration%" > ${mnfo_tpldir:?}/template.txt
  mediainfo --Output=file://${mnfo_tpldir:?}/template.txt "$1"
}

mediainfo_resolution () # ~ <Media-File>
{
  echo "Video;%Width%x%Height%" > ${mnfo_tpldir:?}/template.txt
  mediainfo --Output=file://${mnfo_tpldir:?}/template.txt "$1"
}

mediainfo_pixelaspectratio () # ~ <Media-File>
{
  echo "Video;%PixelAspectRatio/String%" > ${mnfo_tpldir:?}/template.txt
  mediainfo --Output=file://${mnfo_tpldir:?}/template.txt "$1"
}

mediainfo_displayaspectratio () # ~ <Media-File>
{
  echo "Video;%DisplayAspectRatio/String%" > ${mnfo_tpldir:?}/template.txt
  mediainfo --Output=file://${mnfo_tpldir:?}/template.txt "$1"
}

# XXX: mediainfo tpl formats and placeholders:
# General;%CompleteNae% * %FileSize/String3% * %Duration/String%
# Video; |Video: %Width%x%Height% * %DisplayAspectRatio/String% * %Format%
# %Format_Profile%
# Audio; |Audio: %Language/String% * %Channel(s)% CH * %Codec/String%
# Text; |Sub: %Language/String% * %Codec%
# File_End;\n
