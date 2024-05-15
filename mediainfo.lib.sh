mediainfo_lib__load ()
{
  lib_require meta &&
  : "${mdnfo_cache:=${METADIR/cache}}"
}

mediainfo_lib__init ()
{
  echo "General;%Duration%" > ${mdnfo_cache:?}/gen-durms.mdnfo-tpl
  echo "General;%Format%" > ${mdnfo_cache:?}/gen-ffmt.mdnfo-tpl
  echo "Video;%Format%" > ${mdnfo_cache:?}/vid-fmt.mdnfo-tpl
  echo "Video;%DisplayAspectRatio/String%" > ${mdnfo_cache:?}/vid-dar.mdnfo-tpl
  echo "Video;%Width%x%Height%" > ${mdnfo_cache:?}/vid-res.mdnfo-tpl
}


mediainfo_durationms () # ~ <Media-File>
{
  mediainfo --Output=file://${mdnfo_cache:?}/gen-durms.mdnfo-tpl "$1"
}

mediainfo_fileformat () # ~ <Media-File>
{
  mediainfo --Output=file://${mdnfo_cache:?}/gen-ffmt.mdnfo-tpl "$1"
}

mediainfo_resolution () # ~ <Media-File>
{
  mediainfo --Output=file://${mdnfo_cache:?}/vid-res.mdnfo-tpl "$1"
}

mediainfo_pixelaspectratio () # ~ <Media-File>
{
  mediainfo --Output=file://${mdnfo_cache:?}/vid-par.mdnfo-tpl "$1"
}

mediainfo_displayaspectratio () # ~ <Media-File>
{
  mediainfo --Output=file://${mdnfo_cache:?}/vid-dar.mdnfo-tpl "$1"
}

mediainfo_videoformat () # ~ <Media-File>
{
  mediainfo --Output=file://${mdnfo_cache:?}/vid-fmt.mdnfo-tpl "$1"
}

# XXX: mediainfo tpl formats and placeholders:
# General;%CompleteNae% * %FileSize/String3% * %Duration/String%
# Video; |Video: %Width%x%Height% * %DisplayAspectRatio/String% * %Format%
# %Format_Profile%
# Audio; |Audio: %Language/String% * %Channel(s)% CH * %Codec/String%
# Text; |Sub: %Language/String% * %Codec%
# File_End;\n
