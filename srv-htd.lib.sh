srv_htd_lib__load()
{
  #lib_require metadir || return
  lib_require ctx-class stattab-uc || return
  : "${SRVTAB:=${STATUSDIR_ROOT:?}index/srv.tab}"
}

srv_htd_lib__init ()
{
  test -z "${srv_htd_lib_init:-}" || return $_

  create srvtab SrvTab "$SRVTAB"
}


class.SrvTabEntry () # ~ <Instance-Id> .<Message-name> <Args...>
#   .SrvTabEntry <Type> [<Src:Line>] - constructor
{
  test $# -gt 0 || return 177
  test $# -gt 1 || set -- $1 .toString
  local name=SrvTabEntry super_type=StatTabEntry self super id=$1 m=$2
  shift 2
  self="class.$name $id "
  super="class.$super_type $id "

  case "$m" in
    ".$name" )
        $super.$super_type "$@" ;;
    ".__$name" ) $super.__$super_type ;;

    .local-dir ) # Look for another entry in parent table that tags srv/<name>
        tagref=$(printf ' @%s\( \| .* \)host:%s\( \|$\)' $($self.var id) $HOST)
        : "$($self.src)"
        grep "$tagref" $_ | sed 's#^.* <\([^>]*\)/>.*#\1#'
      ;;

    .class-context ) class.info-tree .class-context ;;
    .info | .toString ) class.info ;;

    * ) $super$m "$@" ;;
  esac
}

class.SrvTab () # ~ <Instance-Id> .<Message-name> <Args...>
#   .SrvTab <Type> <Table> [<Entry-class>] - constructor
{
  test $# -gt 0 || return 177
  test $# -gt 1 || set -- $1 .toString
  local name=SrvTab super_type=StatTab self super id=$1 m=$2
  shift 2
  self="class.$name $id "
  super="class.$super_type $id "

  case "$m" in
    ".$name" )
        $super.$super_type "$1" "$2" "${3:-SrvTabEntry}" ;;
    ".__$name" ) $super.__$super_type ;;

    .class-context ) class.info-tree .class-context ;;
    .info | .toString ) class.info ;;

    * ) $super$m "$@" ;;
  esac
}

#
