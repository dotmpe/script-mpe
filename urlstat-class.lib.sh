urlstat_class_lib__load ()
{
  ctx_class_types="${ctx_class_types-}${ctx_class_types+" "}URLStats URLStat"
  : "${urlstat_var_keys:=status btime ctime utime short refs idrefs meta}"

  local urlidx=${URLIDX_NAME:-urls.tab}
  if_ok "${URLIDX:=$(out_fmt= statusdir_lookup ${urlidx:?} index)}" ||
    $LOG alert :stattab "Expected an existing urls index" \
      "E$?:$urlidx" $?
}

# XXX: dont want to record deps for every class/context in load/init hooks
# but have this in AST/src meta otherwise?
#urlstat_class_lib__init ()
#{
#  lib_require stattab-class
#}

class.URLStat.load () # ~
{
  true
}

class.URLStat () # :StatTabEntry ~ <ID> .<METHOD> <ARGS...>
#   .URLStat <Concrete-type> [<Src:Line>]
#   .__URLStat
{
  test $# -gt 0 || return 177
  test $# -gt 1 || set -- "$1" .toString
  local name=URLStat super_type=StatTabEntry self super id=${1:?} m=${2:-}
  shift 2
  self="class.$name $id "
  super="class.$super_type $id "

  case "$m" in
    ".$name" ) $super.$super_type "$@"
      ;;
    ".__$name" ) $super.__$super_type
      ;;

    .class-context ) class.info-tree .tree ;;
    .info | .toString ) class.info ;;

    * ) $super"$m" "$@" ;;
  esac
}

class.URLStats.load () # ~
{
  true
}

class.URLStats () # :StatTab ~ <ID> .<METHOD> <ARGS...>
#   .URLStats <Concrete-type> <Tab-file> <Entry-type>
#   .__URLStats
{
  test $# -gt 0 || return 177
  test $# -gt 1 || set -- "$1" .toString
  local name=URLStats super_type=StatTab self super id=${1:?} m=${2:-}
  shift 2
  self="class.$name $id "
  super="class.$super_type $id "

  case "$m" in
    ".$name" )
        test -e "${2:-}" ||
            $LOG error : "Tab file expected" "$2" 1 || return
        $super.$super_type "$1" "$2" "${3:-URLStat}" || return
      ;;
    ".__$name" ) $super.__$super_type ;;

    .id_from_url ) # ~ <URL> # Find resource class for URL and extract context Id
        urlstat_url_contexts "${1:?}"
      ;;

    .ids ) # ~ <URL> # Look
        urlstat_urlids "${1:?}"
      ;;

    .class-context ) class.info-tree .tree ;;
    .info | .toString ) class.info ;;

    * ) $super"$m" "$@" ;;
  esac
}
