
stattab_class_lib__load ()
{
  ctx_class_types="${ctx_class_types-}${ctx_class_types+" "}StatTabEntry StatTab"
  : "${stattab_var_keys:=status btime ctime utime short refs idrefs meta}"
}

class.StatTabEntry.load () # ~
{
  declare -g -A StatTabEntry__btime=()
  declare -g -A StatTabEntry__ctime=()
  declare -g -A StatTabEntry__utime=()
  declare -g -A StatTabEntry__id=()
  declare -g -A StatTabEntry__short=()
  declare -g -A StatTabEntry__tags=()
}

class.StatTabEntry () # :Class ~ <ID> .<METHOD> <ARGS...>
#   .StatTabEntry <Entry...>
#   XXX: .StatTabEntry <Type> [<Src:Line>] - constructor
#   .tab-ref
#   .tab
#   .get
#   .set
#   .update
#   .commit
{
  test $# -gt 0 || return 177
  test $# -gt 1 || set -- "$1" .toString
  local name=StatTabEntry super_type=Class self super id=${1:?} m=${2:-}
  shift 2
  self="class.$name $id "
  super="class.$super_type $id "

  case "$m" in
    ".$name" ) $super.$super_type "$@"
      ;;
    ".__$name" ) $super.__$super_type
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
        : "StatTabEntry__${1//-/_}[$id]"
        echo "${!_}"
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

    * ) $super"$m" "$@" ;;
  esac
}

class.StatTab () # :Class ~ <ID> .<METHOD> <ARGS...>
#   .StatTab <Tab> [<EntryType>]         - constructor
#   .tab
#   .tab-exists
#   .tab-init
#   .exists <Entry-Id> <Type>
#   .init
#   .fetch <Var-Name> <Entry-Id>
#   .update
#   .commit
{
  test $# -gt 0 || return 177
  test $# -gt 1 || set -- "$1" .toString
  local name=StatTab super_type=Class self super id=${1:?} m=${2:-}
  shift 2
  self="class.$name $id "
  super="class.$super_type $id "

  case "$m" in
    ".$name" )
        test -e "${2:-}" ||
            $LOG error : "Tab file expected" "$2" 1 || return
        $super.$super_type "$1" "$2" "${3:-StatTabEntry}" || return
      ;;
    ".__$name" ) $super.__$super_type ;;

    .tab ) stattab_tab "${1:-}" "$($self.tab-ref)" ;;
    .tab-ref )
        if_ok "$($self.params)" && : "${_/ *}" && echo "$_"
      ;;
    .tab-entry-class )
        if_ok "$($self.params)" && : "${_/* }" && echo "$_"
      ;;
    .tab-exists ) test -s "$($self.tab-ref)" ;;
    .tab-init ) stattab_tab_init "$($self.tab-ref)" ;;
    .list|.ids|.keys ) # ~ [<Key-match>]
        stattab_list "${1:-}" "$($self.tab-ref)"
      ;;

    .exists ) stattab_exists "$1" "" "$($self.tab-ref)" ;;
    .init ) local var=$1; shift
        stattab_init "$@" &&
        create "$var" StatTabEntry "$id"
      ;;
    .fetch ) # ~ <Var-name> <Stat-id>
        : "${1:?Expected Var-name argument}"
        : "${2:?Expected Stat-id argument}"
        stattab_fetch "$_" "" "$($self.tab-ref)" &&
        $LOG info : "Retrieved $($self.class) entry" "$1=$_:E$?" $? &&
        create "$1" $($self.tab-entry-class) "$id" "$stttab_src:$stttab_lineno" &&
        ${!1}.get
      ;;

    .class-context ) class.info-tree .tree ;;
    .info | .toString ) class.info ;;

    * ) $super"$m" "$@" ;;
  esac
}
