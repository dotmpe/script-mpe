#!/usr/bin/env bash

todotxt_lib__load ()
{
  lib_require sys match-htd todotxt-fields class-uc filereader-htd || return
  : "${TTXT_FS:= }"
  : "${TTXT_STATC:="0-9^<>?!$$()&*+.,:~|-"}"
  : "${TTXT_PRIOC:="A-Za-z$TTXT_STATC"}"
  : "${TTXT_PRIOCC:="("}"
  ctx_class_types=${ctx_class_types-}${ctx_class_types:+" "}\
TodoTxtFile\ TodoTxtTask
}


todotxt_from_file ()
{
  if_ok "${1-$($todotxt.attr file FileReader)}" &&
  stdin_from_nonempty "${_:?}"
}

todotxt_grep () # ~ <Id> [<Search-Type>] [<File-source>]
{
  test $# -ge 1 -a -n "${1-}" -a $# -le 3 || return ${_E_GAE:?}

  # Read given stdin or connect given file to stdin
  test ! -t 0 || todotxt_from_file ${3-} || return

  test "unset" != "${grep_f-"unset"}" || local grep_f=-m1
  local act=${2:-} st_ p_; match_grep_arg "$1"
  act=${act:+$(str_globstripcl "${act:?}" -)}
  : "${act:=}"
  prio_="^([$TTXT_PRIOC]*)"
  st_="^[$TTXT_FS$TTXT_STATC]*"
  todotxt_grep_
}

todotxt_grep_ ()
{
  case "${act:?}" in

    ( descr )
        $ggrep $grep_f "$st_\\([^:]*:$p_:\\?\\|.* alias:$p_\\)\\(\\ \\|\$\\)"
      ;;

    ( pairs )
        $ggrep $grep_f "$st_.*$p_" ;;

    ( prio|priority )
        stderr echo prio: $ggrep $grep_f "$st_.*$p_"
        $ggrep $grep_f "$prioc_"
      ;;

    ( ref )
        $ggrep $grep_f "${st_}[^:]*:\? .* <$p_>\( \|\$\)" ;;

    ( tagged )
        $ggrep $grep_f "${st_}.* \(\+\|@\)$p_\( \|\$\)" ;;

      * ) $LOG error :todotxt-grep "No such search-type" "$act" ${_E_nsa:?}
  esac
}

todotxt_tagged () # [todo-txt] ~ [<File>] <Tag-name>
{
  local p_ grep_a
  test -t 0 && {
    test -e "${1-}" && { grep_a="$1" ; shift; } || grep_a=$todo_txt
  } || grep_a=
  test -n "${grep_f-}" || local grep_f=-n
  p_="$(match_grep "${1:?}")"
  #$ggrep $grep_f '^[0-9a-z -]*\b[^ ]*.*\ \(@\|+\)'"$p_"'\(\ \|$\)' $grep_a
  $ggrep $grep_f '^[\t ]*[^#].*\ \(@\|+\)'"$p_"'\(\ \|$\)' $grep_a
}


class_TodoTxtTask__load ()
{
  Class__static_type[TodoTxtTask]=TodoTxtTask:Class
  declare -g -A TodoTxt__file=()
}

class_TodoTxtTask_ ()
{
  case "${call:?}" in

    ( .__init__ )
        TODO "$SELF_NAME $call"
        # ${super:?}.__init__ "$1" "${@:3}" &&
      ;;

      * ) return ${_E_next:?}

  esac && return ${_E_done:?}
}


class_TodoTxtFile__load ()
{
  Class__static_type[TodoTxtFile]=TodoTxtFile:FileReader
  declare -g -A TodoTxtFile__entry_type=()
}

class_TodoTxtFile_ ()
{
  case "${call:?}" in

    ( .__init__ )
        TodoTxtFile__entry_type[$id]=${3:-TodoTxtTask} &&
        ${super:?}.__init__ "${@:1:2}" "${@:4}"
      ;;

    ( .count-tasks )
        $self.list-tasks | count_lines
      ;;

    ( .byPriority )
        todotxt_grep "${1:?}" -priority
      ;;

    ( .list-tasks )
        if_ok "$($self.attr file FileReader)" &&
        read_nix_style_file "$_"
      ;;

    ( .priorities )
        test ! -t 0 || todotxt_from_file "$@" || return
        todotxt_field_prios
      ;;

      * ) return ${_E_next:?}

  esac && return ${_E_done:?}
}


#
