#!/usr/bin/env bash

## Write playlist file based on times and tags

# This writes extended .m3u files and shell scripts using pl.lib.sh

# Usage: writepl <basename> [<tabfile> [<output>]]
# See `pl write`


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
  echo "# ex:nowrap:"
  echo "set -e"
  echo "cd \"$PWD\" || exit \$?"
  echo "test \$# -gt 0 || set -- --fs"
  echo "mpv \\"
  local line=0
  while IFS=$'\t\n' read -ra fields
  do
    unset ${reset_fields:-title tags}
    line=$(( line + 1 ))

    test "${fields[0]:0:1}" = "#" && {
      stderr echo proc $line ${fields[0]}
      #test "${fields[0]:0:19}" = "#reset_fields" && {
      #  declare
      #}
      test "${fields[0]:0:4}" = "#mpv" || continue
      declare docvar="${fields[0]:6}"
      test "${docvar:$(( ${#docvar} - 1 ))}" = " " &&
        docvar="${docvar:0:$(( ${#docvar} - 1 ))}" ||
        docvar="${docvar/ /=}"
      echo "  --${docvar//_/-} \\"
      continue
    }
    test 3 -eq ${#fields} || {
      for f in "${fields[@]:3}"
      do
        declare ${f/=*}="${f/*=}"
      done
    }
    #test 2 -le ${#fields} ||
    #  $LOG error : "Expected two or more fields" "L$line" 1 || return
    p="${fields[2]:-}"
    #test -n "$p" ||
    #  $LOG error : "Expected 3 fields" "L$line" 1 || return
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
  echo "  \"\$@\""
  echo "# Generated: $(date) $0 writepl-sh-mpv"
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
#
# <https://docs.fileformat.com/audio/m3u/>
#
# Have not found equiv of VLCOPT:{start,stop}-time
# I wonder if subplaylists and M3U's #EXT-X-START works anywhere.
#
# Chapters files for mpv player https://github.com/mpv-player/mpv/issues/4446
# FFMPEG chapters: http://ffmpeg.org/ffmpeg-formats.html#Metadata-1


# Main script entry

set -euo pipefail

true "${US_BIN:="$HOME/bin"}"
. "${US_BIN:?}/pl.lib.sh"
. "${US_BIN:?}/pl.sh"

test $# -gt 0 || set -- main
pl_loadenv
update "$@"

#
