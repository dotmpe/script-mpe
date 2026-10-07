urlstat_class_lib__load ()
{
  ctx_class_types="${ctx_class_types-}${ctx_class_types:+" "}URLStats URLStat"
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

class_URLStat__load () # ~
{
  Class__static_type[URLStat]=URLStat:StatTabEntry
}

class_URLStat_ () # :StatTabEntry ~ <ID> .<METHOD> <ARGS...>
#   .URLStat <Concrete-type> [<Src:Line>]
#   .__URLStat
{
  case "${call:?}" in

      * ) return ${_E_next:?};

  esac && return ${_E_done:?}
}


class_URLStats__load () # ~
{
  Class__static_type[URLStats]=URLStats:StatTab
}

class_URLStats_ () # :StatTab ~ <ID> .<METHOD> <ARGS...>
#   .URLStats <Concrete-type> <Tab-file> <Entry-type>
#   .__URLStats
{
  case "${call:?}" in
    ( ".__init__" )
        test -e "${2:-}" ||
            $LOG error : "Tab file expected" "$2" 1 || return
        $super.__init__ "$1" "$2" "${3:-URLStat}" || return
      ;;

    .id_from_url ) # ~ <URL> # Find resource class for URL and extract context Id
        urlstat_url_contexts "${1:?}"
      ;;

    .ids ) # ~ <URL> # Look
        urlstat_urlids "${1:?}"
      ;;

      * ) return ${_E_next:?};

  esac && return ${_E_done:?}
}
