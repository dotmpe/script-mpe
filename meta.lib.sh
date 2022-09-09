#!/bin/sh


meta_lib_load ()
{
  test -n "${META_DIR-}" || META_DIR=.meta
}

# Return mime-type (from BSD/GNU file) on Linux and Darwin
file_mime()
{
  test -e "$1" || error "expected existing path <$1>" 1
  case "$uname" in

    Darwin ) file -b --mime-type "$1" ;;
    Linux ) file -bi "$1" ;;

    * ) error "No file MIME-type on $uname" 1 ;;

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

meta_api_man_1='
  attributes
  emby-list-images [$DKCR_VOL/emby/config]
'

meta_attribute()
{
  test -e .attributes || return
  test -n "$1" || error meta-attributes-act 1
  case "$1" in
    tagged )
        test -n "$2" || set -- "$1" "src"
        grep $2 .attributes | cut -f 1 -d ' '
      ;;
  esac
}


json_to_csv()
{
  test -n "$1" || error "JQ selector req" 1 # .path.to.items[]
  local jq_sel="$1" ; shift ;
  test -n "$*" || error "One or more attribute names expected" 1
  trueish "$csv_header" &&
    { echo "$*" | tr ' ' ',' ; } || { echo "# $*" ; }

  local _s="$(echo "$*"|words_to_lines|awk '{print "."$1}'|lines_to_words)"
  jq -r "$jq_sel"' | ['"$(echo $_s|wordsep ',')"'] | @csv'
}


# Id: script-mpe/0.0.4-dev meta.lib.sh
