tabfile_lib__load ()
{
  lib_require sys str match-htd || return
}

tabfile_grep () # ~ <Key> [<Search-Type>] [<Tab-file>]
{
  test $# -ge 1 -a -n "${1-}" -a $# -le 3 || return ${_E_GAE:?}
  test ! -t 0 || stdin_from_nonempty "${3-}" || return

  test "unset" != "${grep_f-"unset"}" || local grep_f=-m1
  local act=${2:-} fs_ p_; match_grep_arg "$1"
  act=${act:+$(str_globstripcl "${act:?}" -)}
  : "${act:=local}"
  fs_="${tf_fs:-\t}"
  tabfile_grep_
}

tabfile_grep_ ()
{
  case "${act:?}" in

    ( val )
        stderr echo "grep ${grep_f-} '\\(^\\|$fs_\\)$p_\\($\\|$fs_\\)'"
        grep ${grep_f-} "\\(^\\|$fs_\\)$p_\\($\\|$fs_\\)"
      ;;

      * ) $LOG error :tabfile-grep "No such search-type" "$act" ${_E_nsa:?}
  esac
}
