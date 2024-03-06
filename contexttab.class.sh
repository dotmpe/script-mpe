
class_ContextTab__load () # ~
{
  uc_class_declare ContextTab StatTab --libs context,class-uc,stattab-uc \
    --static-methods
  : "${contexttab_methods:=}"
}

class_ContextTab_ () # :ParameterizedClass ~ <Instance-Id> .<Method> <Args...>
# Methods:
#   .ContextTab <Instance-Type> <Table> [<Entry-class>] - constructor
#   .__ContextTab - destructor
#
# ContextTab routines:
#
# ContextTab parameters:
{
  fnmatch "* ${call:1} *" " $contexttab_methods " && {
    # And all these static context methods are already defined
    at_ContextTab=$self context_${call:1} "$@"
    return
  }
  case "${call:?}" in

    ( .cache-taglist ) # ~ <Var-name=taglist> <Cache-file>
        local tc=${CACHE_DIR:?}/${2:-sort-context-tags.list}
        test -e "$tc" -a $tc -nt ${CTX_TAB_CACHE:?} || {
          context_tags_list >| "$tc" || return
        }
        declare -g ${1:-taglist}=$tc
      ;;

    ( .up-to-date ) context_files | os_up_to_date "${CTX_TAB_CACHE:?}"
      ;;

      * ) return ${_E_next:?}

  esac &&
    return ${_E_done:?}
}

#
