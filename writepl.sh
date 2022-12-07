#!/bin/sh

## Write playlist file based on times and tags

# This writes extended .m3u files


time2seconds ()
{
  { test $# -gt 0 && {
    echo "$1"
  } || {
    cat
  } ; } |
    awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }'
}

# (Media should not be longer than 99 hours)
stdtime ()
{
  stdtc=$(echo "$1" | tr -dc ':')
  while test ${#stdtc} -lt 2
  do set -- "00:$1"; stdtc="$stdtc:"
  done
  unset stdtc
  echo "$1"
}

matches ()
{
  any=false
  for a in "$@"
  do
    case " $comment " in
      ( *" $a "* ) any=true ; break ;;
      ( * ) ;;
    esac
  done
  $any
}

eval_pi ()
{
  test "${1:1:1}" = ":" || {
    $LOG error "" "Unknown preproc dir" "$1"
    return 1
  }
  typeset dir="${1:2}" var val
  var=${dir%:*}
  var=${var//:/__}
  var=${var//[^[:alnum:]_]/_}
  val="${dir/*:}"
  val="${val/ }"
  shift
  test $# -gt 0 && val="$val $*"
  typeset -g "VAR=$var" "VAL=$val" "$var=$val"
  test ${v:-4} -le 5 || typeset -p "$var" >&2
}

eval_doc_pi ()
{
  eval_pi "${1/\#:/\#:list:}"
}

eval_item_pi ()
{
  eval_pi "${1/\#:/\#:item:}" || return
  declare docvar="list__${VAR:6}" docval

  # Combine with document level value when
  # 1. starts with space, 2. substitue every ~ occurence
  test -z "${!docvar:-}" && return
  docval=$_
  test "${VAL:0:1}" = " " && {
    VAL="~ $VAL"
  }
  typeset -g VAL="${VAL//\~/$docval}"
  typeset -g $VAR="$VAL"
}

# Output tabfile specs to M3U playlist. Select lines based on tags in comment
readtab () # ~ [<Tags...>]
{
  true "${rest_default:="#"}"
  true "${rest_empty:="#"}"

  typeset -a extra=()
  grep -vE '^\s*(|# .*)$' |
    sed -e 's/^ *//' -e 's/ *$//' -e 's/^#/# # #/' |
    while read st et f rest
  do
    test "${st:0:1}" = "#" && {
      test "${f:1:1}" != ":" || {
        eval_doc_pi "$f $rest" || return
        echo "#$VAR $VAL"
      }
      continue
    }

    test -e "$st" && {
      # Special case, set current file-path if first value exists, ignore rest
      p="${Dir:-}${Dir:+/}$st"
      extra=()
      continue
    }

    # Another special case, comments or parse additional data for current item
    case "$f" in
      ( "#:"* ) rest="$f $rest"; f= ;;
      ( "#"* ) continue ;;
    esac

    test -z "$f" && {
      test -e "${p:-}" || {
        test -h "${p:-}" && continue
        $LOG error "" "No such file" "$st $et $f $rest"
        continue
      }
    } || {
      test -e "$f" || {
        test -n "${Dir:-}" -a -e "${Dir:-}/$f" && {
          echo Found f="$Dir/$f" >&2
          f="$Dir/$f"
        } || {
          test -z "${Dir:-}" || echo Invalid Dir path, missing f="$Dir/$f" >&2
          f=$(find . -iname "$f" -print -quit)
        }
      }
      test -e "$f" || {
        echo "No such file <$f>" >&2
        continue
      }
      p="$f"
      extra=()
    }

    test -z "$rest" || {
      eval_item_pi "${rest}"
      extra+=("${VAR:6}=$VAL")
    }

    # Match for tags?
    #test $# -eq 0 || {

    #  test -n "$rest" || rest=$rest_default
    #  test "$rest" != "#" || rest=$rest_empty

    #  case "$rest" in ( "#"* )
    #      comment="$rest" matches "$@" || continue
    #  ;; esac
    #}

    # Just set file, dont output; timespecs follow
    test "$st $et" = "- -" && {
      continue
    }

    # Don't include timespec with playlist entry (play entire file)
    test "$st $et" = "* *" && {
      st=0 et=-
    }

    printf "%s\t%s\t%s%s\n" "$st" "$et" "$p" "$(printf "\\t%s" "${extra[@]:-}")"
  done
}


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
      #test "${fields[0]:0:19}" = "#list__reset_fields" && {
      #  declare
      #}
      test "${fields[0]:0:10}" = "#list__mpv" || continue
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
