#!/bin/sh

## Write playlist file based on times and tags

# This writes extended .m3u files and shell scripts.


writepl_raw ()
{
  cat
}

writepl_fields ()
{
  while IFS=$'\t\n' read -ra fields
  do
    test "${fields[0]:0:1}" = "#" && continue
    echo "${#fields} ${fields[4]:-}"
  done
}

writepl_kv ()
{
  while IFS=$'\t\n' read -r st et p extra
  do
    test "${st:0:1}" = "#" && continue
    test "$st" = "0" && {
      test "${et:--}" = "-" && {
        echo "path=$p extra=$extra"
      } || {
        echo "end=$et path=$p extra=$extra"
      }
    } || {
      echo "start=$st end=$et path=$p extra=$extra"
    }
  done
}

# This 'works' as playlist except it cannot be navigated
writepl_sh_mpv ()
{
  declare docvar
  echo "set -e"
  echo "cd \"$PWD\" || exit"
  echo "mpv --fs \\"
  while IFS=$'\t\n' read -ra fields
  do
    unset ${reset_fields:-title tags}
    test "${fields[0]:0:1}" = "#" && {
      #test "${fields[0]:0:19}" = "#reset_fields" && {
      #  declare
      #}
      test "${fields[0]:0:10}" = "#mpv" || continue
      declare docvar="${fields[0]:7}"
      docvar="${docvar/ /=}"
      echo "  --${docvar/mpv__} \\"
      continue
    }
    test 3 -eq ${#fields} || {
      for f in "${fields[@]:3}"
      do
        declare ${f/=*}="${f/*=}"
      done
    }
    p="${fields[2]}"
    bn=$(basename "$p")
    bn=${bn%.*}
    test "${fields[0]}" = "0" && {
      test "${fields[1]:--}" = "-" && {
        echo "  --\{ --force-media-title=\"${title:-$bn}\" \"$p\" --\} \\"
      } || {
        echo "  --\{ --end=${fields[1]} --force-media-title=\"${title:-$bn}\" \"$p\" --\} \\"
      }
    } || {
      test "${fields[1]:--}" = "-" && {
        echo "  --\{ --start=${fields[0]} --force-media-title=\"${title:-$bn}\" \"$p\" --\} \\"
      } || {
        echo "  --\{ --start=${fields[0]} --end=${fields[1]} --force-media-title=\"${title:-$bn}\" \"$p\" --\} \\"
      }
    }
  done
  echo
  echo "# Generated: $(date) $0 writepl-m3u-vlc"
}

# MPlayer/MPV EDL playlists
writepl_mp_edl ()
{
  while IFS=$'\t\n' read -r st et p extra
  do
    sts=$(time2seconds "$(stdtime "$st")")
    ste=$(time2seconds "$(stdtime "$et")")
    cat <<EOM
0 $sts 0
$ste 0 0
EOM
  done
}

# VLC specific extended M3U file with video clips
writepl_m3u_vlc ()
{
  echo "#EXTM3U"
  echo "#EXTENC:utf-8"
  echo "#PLAYLIST:${M3U_TITLE:-${bn}}"
  while IFS=$'\t\n' read -r st et p extra
  do
    test "$st" = "0" || {
      sts=$(time2seconds "$(stdtime "$st")")
      echo "#EXTVLCOPT:start-time=$sts"
    }
    test "${et:--}" = "-" || {
      ste=$(time2seconds "$(stdtime "$et")")
      echo "#EXTVLCOPT:stop-time=$ste"
    }
    echo "$p"
  done
  echo "#EXT-X-ENDLIST"
  echo "# Generated: $(date) $0 writepl-m3u-vlc"
}

# XXX: here is some docs on chapter files, but not much for playlists.
# Not sure what the purpose for M3U #EXT-X-START is
#
# <https://docs.fileformat.com/audio/m3u/>
#
# Chapters files for mpv player https://github.com/mpv-player/mpv/issues/4446
# FFMPEG chapters: http://ffmpeg.org/ffmpeg-formats.html#Metadata-1


# Main script entry

set -euo pipefail

true "${US_BIN:="$HOME/bin"}"
. "${US_BIN:?}/pl.lib.sh"
. "${US_BIN:?}/tools/sh/parts/fnmatch.sh"


bn=${1:-main}
test $# -eq 0 || shift

ext=${bn#*.}
bn=${bn%%.*}
ext=${ext:-vlc.m3u}
reader=$(printf '%s\n' ${ext//./ } | tac)
reader=${reader//$'\n'/_}

test $# -eq 0 && {
  test -e ${bn:?}.${ext:?} \
    -a ${bn:?}.${ext:?} -nt ${bn:?}.tab && {

    echo "File '${bn}.${ext}' is up to date with $bn.tab" >&2

  } || {
    echo "Writing '${bn}.${ext}' from $bn.tab (writepl_${reader//$'\n'/_})" >&2
    {
      readtab < ${bn:?}.tab
    } | writepl_${reader} > ${bn:?}.${ext:?}
  }
} || {
  # echo "Output as '${bn}.${ext}' from $bn.tab (writepl_${reader//$'\n'/_})" >&2
  {
    test "${1:-}" = "-" && {
      cat || $LOG error "" "" "E$?" $?
      exit $?
    } || {
      test -z "${1:-}" && {
        readtab < ${bn:?}.tab || $LOG error "" "Reading tab" "E$?:$bn.tab" $?
        exit $?
      } || {
        readtab < "${1}" || $LOG error "" "Reading tab" "E$?:$1" $?
        exit $?
      }
    }
  } | writepl_${reader} | {
    test "${2:-}" = "-" && {
      cat || $LOG error "" "" "E$?" $?
      exit $?
    } || {
      #test -z "${1:-}" && {
      cat >> "${2:?}"
    }
  }
}

#
