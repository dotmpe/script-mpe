
stattab_class_lib__load ()
{
  ctx_class_types="${ctx_class_types-}${ctx_class_types:+" "}StatTabEntry StatTab"
  : "${stattab_var_keys:=btime ctime id idrefs meta refs short status utime}"
}

stattab_class_lib__init () # ~
{
  test -z "${stattab_class_lib_init:-}" || return $_
  lib_require stattab stattab-reader || return
}


class_StatTabEntry__load () # ~
{
  Class__static_type[StatTabEntry]=StatTabEntry:ParameterizedClass
  ctx_pclass_params=${ctx_pclass_params:-}${ctx_pclass_params:+ }$stattab_var_keys
  declare -g -A StatTabEntry__btime=()
  declare -g -A StatTabEntry__ctime=()
  declare -g -A StatTabEntry__id=()
  declare -g -A StatTabEntry__idrefs=()
  declare -g -A StatTabEntry__meta=()
  declare -g -A StatTabEntry__short=()
  declare -g -A StatTabEntry__refs=()
  declare -g -A StatTabEntry__status=()
  declare -g -A StatTabEntry__tags=()
  declare -g -A StatTabEntry__utime=()
}

class_StatTabEntry_ () # (super,self,id,call) ~ <ARGS...>
#   .__init__ <Entry...>
#   XXX: .__init__ <Type> [<Src:Line>] - constructor
#   .tab-ref
#   .tab
#   .get
#   .set
#   .update
#   .commit
{
  case "${call:?}" in
    .__del__ ) $super.__del__
        unset StatTabEntry__status[$id]
        unset StatTabEntry__btime[$id]
        unset StatTabEntry__ctime[$id]
        unset StatTabEntry__utime[$id]
        unset StatTabEntry__id[$id]
        unset StatTabEntry__short[$id]
        unset StatTabEntry__tags[$id]
        unset StatTabEntry__refs[$id]
      ;;

    .tab-id )
      if_ok "$($self.params)" && echo "${_/ *}" ;;
    .tab-class )
      if_ok "$($self.tab-id)" && echo "$(class.Class $_ .class)" ;;
    .tab-ref )
      if_ok "$($self.tab-id)" && echo "class.$(class.Class $_ .class) $_ " ;;
    .srcspec )
      if_ok "$($self.params)" && echo "${_/* }" ;;
    .src )
      if_ok "$($self.srcspec)" && echo "${_/:*}" ;;
    .line )
      if_ok "$($self.srcspec)" && echo "${_/*:}" ;;

    .tab ) $($self.tab-ref).tab ;;

    .get )
        StatTabEntry__status[$id]=$stttab_status
        StatTabEntry__btime[$id]=$stttab_btime
        StatTabEntry__ctime[$id]=$stttab_ctime
        StatTabEntry__utime[$id]=$stttab_utime
        StatTabEntry__id[$id]=$stttab_id
        StatTabEntry__short[$id]=$stttab_short
        StatTabEntry__tags[$id]=$stttab_tags
        StatTabEntry__refs[$id]=$stttab_refs
      ;;
    .set )
        stttab_status=${StatTabEntry__status[$id]}
        stttab_btime=${StatTabEntry__btime[$id]}
        stttab_ctime=${StatTabEntry__ctime[$id]}
        stttab_utime=${StatTabEntry__utime[$id]}
        stttab_id=${StatTabEntry__id[$id]}
        stttab_short=${StatTabEntry__short[$id]}
        stttab_tags=${StatTabEntry__tags[$id]}
        stttab_refs=${StatTabEntry__refs[$id]}
      ;;

    .update )
        $self.set &&
        stattab_update "$@" &&
        $self.get
      ;;
    .commit )
        $self.set &&
        stattab_commit $($($self.tab-ref).tab-ref)
      ;;

    .attr ) # ~ <Name-key>           # Get field value from class instance value
        : "StatTabEntry__${1//-/_}[${id:?}]"
        ! "${stb_atr_req:-false}" "$_" &&
          : "${!_:--}" ||
          : "${!_}"
        test - != "$_" &&
          echo "$_" || return ${_E_next:?}
      ;;
    .var ) # ~ <Var-key>             # Get field value from regular env variable
        : "stttab_${1//-/_}"
        echo "${!_}"
      ;;

    .todotxt-field ) # ~ <Field-key>
        #local field=${1:?}
        #shift
        #todotxt_field_${field//-/_} <<< "$"
      ;;

    .toString )
        echo \
          $($self.attr status) \
          $($self.attr btime) \
          $($self.attr ctime) \
          $($self.attr utime) \
          $($self.attr id) \
          $($self.attr short) \
          $($self.attr refs) \
          $($self.attr tags)
      ;;

    .class-context ) class.info-tree .tree ;;
    .info ) class.info ;;

    ( * ) return ${_E_next:?} ;;
  esac ||
    return
  return ${_E_done:?}
}


class_StatTab__load ()
{
  Class__static_type[StatTab]=StatTab:ParameterizedClass
}

# StatTab is a list of StatTabEntries, represented by a single file.
class_StatTab_ () # ~
#   .__init__ <ConcreteType> <Tab> [<EntryType>]         - constructor
#   .tab
#   .tab-exists
#   .tab-init
#   .exists <Entry-Id> <Type>
#   .init
#   .fetch <Var-Name> <Entry-Id>
#   .update
#   .commit
{
  case "${call:?}" in
    .__init__ )
        test -e "${2:-}" ||
            $LOG error : "Tab file expected" "${2:-\$2:unset}" 1 || return
        $super.__init__ "$1" "$2" "${3:-StatTabEntry}" || return
      ;;

    .exists ) # ~ <Id>
        stattab_exists "$1" "" "$($self.tab-ref)" ;;
    .fetch ) # ~ <Var-name> <Stat-id>
        : "${1:?Expected Var-name argument}"
        : "${2:?Expected Stat-id argument}"
        $LOG debug : "Retrieving $($self.class) entry" "$1=$2" &&
        if_ok "$($self.tab-ref)" &&
        stattab_fetch "$2" "" "$_" &&
        $LOG info : "Retrieved $($self.class) entry" "$1=$2:E$?" $? &&
        : "$($self.tab-entry-class)" &&
        create "$1" "$_" "$id" "$stttab_src:$stttab_lineno" &&
        : "${1//local:}" &&
        ${!_}.get
      ;;
    .init ) local var=$1; shift
        stattab_init "$@" &&
        create "$var" StatTabEntry "$id"
      ;;
    .list|.ids|.keys ) # ~ [<Key-match>]
        stattab_list "${1:-}" "$($self.tab-ref)"
      ;;
    .new ) # ~ [<>]
        local tbref dtnow
        tbref="$($self.tab-ref)" &&
        dtnow="$(date_id $(date --iso=min))" &&
        echo "- $dtnow $1:" >> "$tbref"
      ;;
    .status ) # ~ [<>]
        # XXX: refresh status context_run_hook stat || return
        #local entry status
        $self.fetch local:entry "$1" &&
          test -n "${entry-}" || return ${_E_NF:?}
        status=$($entry.attr status) &&
        test -n "$status" &&
        ! fnmatch "[${stb_pri_sep:?}]" "$_" && {
          test 0 = "$_" ||
          fnmatch "*[${stb_pri_sep:?}]0" "$_"
        }
      ;;
    .tab ) stattab_tab "${1:-}" "$($self.tab-ref)" ;;
    .tab-entry-class )
        if_ok "$($self.params)" && : "${_/* }" && echo "$_"
      ;;
    .tab-exists ) test -s "$($self.tab-ref)" ;;
    .tab-init ) stattab_tab_init "$($self.tab-ref)" ;;
    .tab-ref )
        if_ok "$($self.params)" && : "${_/ *}" && echo "$_"
      ;;

    ( * ) return ${_E_next:?} ;;
  esac ||
    return
  return ${_E_done:?}
}
