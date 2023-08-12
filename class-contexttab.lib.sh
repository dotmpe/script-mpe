
class_contexttab_lib__load ()
{
  lib_require context ctx-class stattab-uc || return
  ctx_class_types=${ctx_class_types-}${ctx_class_types+" "}ContextTab
  : "${contexttab_methods:=}"
}


class.ContextTab () # :ParameterizedClass ~ <Instance-Id> .<Method> <Args...>
# Methods:
#   .ContextTab <Instance-Type> <Table> [<Entry-class>] - constructor
#   .__ContextTab - destructor
#
# ContextTab routines:
#
# ContextTab parameters:
{
  local name=ContextTab super_type=StatTab self super id=${1:?} m=$2
  shift 2
  self="class.$name $id "
  super="class.$super_type $id "

  fnmatch "* ${m:1} *" " $contexttab_methods " && {
    # And all these static context methods are already defined
    at_ContextTab=$self context_${m:1} "$@"
    return
  }
  case "$m" in
    ( ".$name" )
        $super.$super_type "$1" "$2" "${3:-StatTabEntry}" ;;
    ( ".__$name" ) $super".__$super_type" ;;

    ( .class-context ) class.info-tree .class-context ;;
    ( .info | .toString ) class.info ;;

    ( .cache-taglist ) # ~ <Var-name=taglist> <Cache-file>
        local tc=${CACHE_DIR:?}/${2:-sort-context-tags.list}
        test -e "$tc" -a $tc -nt ${CTX_TAB_CACHE:?} || {
          context_tags_list >| "$tc" || return
        }
        declare -g ${1:-taglist}=$tc
      ;;
    ( .up-to-date ) context_files | os_up_to_date "${CTX_TAB_CACHE:?}"
      ;;

    ( * ) $super"$m" "$@" ;;
  esac
}

#
