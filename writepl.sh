#!/bin/sh

## Write playlist file based on times and tags

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
  for a in $@
  do
    case " $comment " in
      ( *" $a "* ) any=true ; break ;;
      ( * ) ;;
    esac
  done
  $any
}

# Output tabfile specs to M3U playlist. Select lines based on tags in comment
readtab () # ~ [<Tags...>]
{
  echo "#EXTM3U"

  #
  true "${rest_default:="#"}"
  true "${rest_empty:="#"}"

  grep -vE '^\s*(|#.*)$' | sed -e 's/^ *//' -e 's/ *$//' | while read st et f rest
  do
    test -e "$st" && {
      # Special case, set current file-path if first value exists, ignore rest
      echo
      p="$st"
      continue
    }

    case "$f" in ( "#"* ) f= rest="# $rest" ;; esac

    # Match for tags?
    test $# -eq 0 || {

      test -n "$rest" || rest=$rest_default
      test "$rest" != "#" || rest=$rest_empty

      case "$rest" in ( "#"* )
          comment="$rest" matches "$@" || continue
      :; esac
    }

    test -z "$f" -o -e "$f" || {
      f=$(find . -iname "$f" -print -quit)
    }

    test -e "$p" -o -e "$f" || {
      echo "Not a file <$f>" >&2
      continue
    }

    test -n "$f" && {
      echo
      p="$f"
    }

    # Just set file, dont output; timespecs follow
    test "$st $et" = "- -" && {
      continue
    }

    # Don't include timespec
    test "$st $et" = "* *" && {
      echo "$p"
      continue
    }

    # Print clip
    sts=$(time2seconds "$(stdtime "$st")")
    ste=$(time2seconds "$(stdtime "$et")")
    cat <<EOM
#EXTVLCOPT:start-time=$sts
#EXTVLCOPT:stop-time=$ste
$p
EOM
  done

  echo
  echo "# Generated: $(date) $0 $*"
}

bn=${1:-main}
test $# -eq 0 || shift

{
  readtab "$@" < $bn.tab
} > $bn.m3u
