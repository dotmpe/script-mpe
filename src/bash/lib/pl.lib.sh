#!/usr/bin/bash

### Playlist lib


time2seconds ()
{
  case "${1:?}" in ( *":"* )
      echo "$1" | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }' ;;
    * ) echo "$1"
  esac
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

matches () # (Values) ~ <Query <...>>
{
  any=false
  read -r tags
  for q in "$@"
  do
    case " $tags " in
      ( *" $q "* ) any=true ; break ;;
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
  declare dir="${1:2}" var val
  var=${dir%: *}
  var=${var//:/__}
  var=${var//[^[:alnum:]_]/_}

  val="${dir#*: }"
  shift
  test $# -gt 0 && val="$val $*"
  stderr echo declare "VAR=$var" "VAL=$val" "$var=$val"
  declare -g "VAR=$var" "VAL=$val" "$var=$val"
  test ${v:-4} -le 5 || declare -p "$var" >&2
}

eval_doc_pi ()
{
  eval_pi "${1}"
}

eval_item_pi ()
{
  eval_pi "${1/\#:/\#:item:}" || return
  declare docvar="${VAR:6}" docval

  # Combine with document level value when
  # 1. starts with space, 2. substitue every ~ occurence
  test -z "${!docvar:-}" && return
  docval=$_
  test "${VAL:0:1}" = " " && {
    VAL="~ $VAL"
  }
  declare -g VAL="${VAL//\~/$docval}"
  declare -g $VAR="$VAL"
}

# Output tabfile specs to M3U playlist. Select lines based on tags in comment
readtab () # ~ [<Tags...>]
{
  true "${rest_default:="#"}"
  true "${rest_empty:="#"}"

  declare -a extra=()
  grep -vE '^\s*(# .*)?$' |
    sed -e 's/^ *//' -e 's/ *$//' -e 's/^#/# # #/' | {

    #shellcheck disable=2162 # Current format depends on backslash escapes
    while read st et f rest
    do
      # Eval '#:' prefix as document-level PI, skip other comment lines
      test "${st:0:1}" = "#" && {
        test "${f:1:1}" != ":" || {
          eval_doc_pi "$f${rest:+ }$rest" || return
          echo "#$VAR $VAL"
        }
        continue
      }

      test -e "${Dir:-}${Dir:+/}$st" && {
        # Special case, set current file-path if first value exists, ignore rest
        p="${Dir:-}${Dir:+/}$st"
        extra=()
        continue
      }

      # Another special case, comments or parse additional data for current item
      test "$f" != "#" || f="#:Tags:"
      case "$f" in
        ( "#:"* ) rest="$f $rest"; f= ;;
        ( "#"* ) continue ;;
      esac

      test -z "$f" && {
        test -e "${p:-}" || {
          test -h "${p:-}" && {
            $LOG debug "" "Skipped missing symlink" "$p"
          } || {
            $LOG error "" "No such file (ignored)" "$st $et $f $rest"
          }
          continue
        }
      } || {
        test -e "$f" || {
          test -n "${Dir:-}" -a -e "${Dir:-}/$f" && {
            f="$Dir/$f"
          } || {
            test -z "${Dir:-}" || {
              caller >&2
              $LOG error "" "Invalid Dir path (missing file)" "f=$Dir/$f:st=$st:et=$et:rest=$rest"
            }
            ${pl_find:-true} || {
              $LOG warn "" "Ignored missing" "$f"
              continue
            }
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
      test 0 -eq $# || {
        test 0 -eq ${#extra[@]} && continue
        test "Tags=" = "${extra[0]:0:5}" || continue

        echo "${extra[0]:5}" | matches "${@:?}" || continue
      }

      # Just set file, dont output; timespecs follow
      test "$st $et" = "- -" && {
        continue
      }

      # Don't include timespec with playlist entry (play entire file)
      test "$st $et" = "* *" && {
        st=0 et=-
      }

      : "$(printf "\\t%s" "${extra[@]:-}")" &&
      printf "%s\t%s\t%s%s\n" "$st" "$et" "$p" "$_" || return

      extra=()
    done
  }
}


#
