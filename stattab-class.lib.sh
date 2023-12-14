
stattab_class_lib__load ()
{
  ctx_class_types="${ctx_class_types-}${ctx_class_types:+" "}StatTabEntry StatTab IndexEntry"
  : "${stattab_var_keys:=btime ctime id idrefs meta refs short status utime}"
}

stattab_class_lib__init () # ~
{
  test -z "${stattab_class_lib_init:-}" || return $_
  lib_require stattab stattab-reader || return
}


class_IndexEntry__load () # ~
{
  Class__static_type[IndexEntry]=IndexEntry:StatTabEntry:StatTab
}

class_IndexEntry_ () # (super,self,id,call) ~ <Call ...>
{
  case "${call:?}" in
      * ) return ${_E_next:?};
  esac && return ${_E_done:?}
}


class_StatTabEntry__load () # ~
{
  Class__static_type[StatTabEntry]=StatTabEntry:Class
  #ParameterizedClass
  ctx_pclass_params=${ctx_pclass_params:-}${ctx_pclass_params:+ }$stattab_var_keys
  declare -g -A StatTabEntry__btime=()
  declare -g -A StatTabEntry__ctime=()
  declare -g -A StatTabEntry__id=()
  declare -g -A StatTabEntry__idrefs=()
  declare -g -A StatTabEntry__meta=()
  declare -g -A StatTabEntry__meta_keys=()
  declare -g -A StatTabEntry__short=()
  declare -g -A StatTabEntry__refs=()
  declare -g -A StatTabEntry__stattab=()
  declare -g -A StatTabEntry__status=()
  declare -g -A StatTabEntry__seqidx=()
  declare -g -A StatTabEntry__tags=()
  declare -g -A StatTabEntry__utime=()
}

class_StatTabEntry_ () # (super,self,id,call) ~ <ARGS...>
#   .__init__ <ConcreteType> <Tab-Id> <Tab-Seq> <...>
#   .__del__
#   .tab-ref
#   .tab
#   .get
#   .set
#   .update
#   .commit
{
  case "${call:?}" in
    .__init__ )
        StatTabEntry__stattab[$id]=${2:?} &&
        StatTabEntry__seqidx[$id]=${3:?} &&
        StatTabEntry__status[$id]=- &&
        StatTabEntry__btime[$id]=- &&
        StatTabEntry__ctime[$id]=- &&
        ${super:?}.__init__ "$1" "${@:4}"
      ;;
    .__del__ )
        unset StatTabEntry__stattab[$id] &&
        unset StatTabEntry__seqidx[$id] &&
        unset StatTabEntry__status[$id] &&
        unset StatTabEntry__btime[$id] &&
        unset StatTabEntry__ctime[$id] &&
        unset StatTabEntry__utime[$id] &&
        unset StatTabEntry__id[$id] &&
        unset StatTabEntry__short[$id] &&
        unset StatTabEntry__tags[$id] &&
        unset StatTabEntry__refs[$id] &&
        unset StatTabEntry__idrefs[$id] &&
        unset StatTabEntry__meta[$id] &&
        stattab_meta_unset StatTabEntry__meta &&
        ${super:?}.__del__
      ;;
    .attr ) # ~ <Key> [<Class>]          # Get field value from class instance value
        $super.attr "$1" "${2:-StatTabEntry}" ${3:-} ;;
    .commit )
        $self.set &&
        stattab_commit $($($self.tab).tab-ref)
      ;;
    .entry ) stattab_entry "$@"
      ;;
    .get )
        StatTabEntry__status[$id]=$stttab_status
        StatTabEntry__btime[$id]=$stttab_btime
        StatTabEntry__ctime[$id]=$stttab_ctime
        StatTabEntry__utime[$id]=$stttab_utime
        StatTabEntry__id[$id]=$stttab_id
        StatTabEntry__short[$id]=$stttab_short
        StatTabEntry__tags[$id]=$stttab_tags
        StatTabEntry__refs[$id]=$stttab_refs
        StatTabEntry__idrefs[$id]=$stttab_idrefs
        stattab_meta_parse StatTabEntry__meta
      ;;
    .line )
      if_ok "$($self.srcspec)" && echo "${_/*:}" ;;
    .set )
        ! stattab_value "${StatTabEntry__status[$id]-}" || stttab_status=$_
        ! stattab_value "${StatTabEntry__btime[$id]}"  || stttab_btime=$_
        ! stattab_value "${StatTabEntry__ctime[$id]}"  || stttab_ctime=$_
        ! stattab_value "${StatTabEntry__utime[$id]-}"  || stttab_utime=$_
        ! stattab_value "${StatTabEntry__id[$id]-}"     || stttab_id=$_
        ! stattab_value "${StatTabEntry__short[$id]-}"  || stttab_short=$_
        ! stattab_value "${StatTabEntry__tags[$id]-}"   || stttab_tags=$_
        ! stattab_value "${StatTabEntry__refs[$id]-}"   || stttab_refs=$_
        ! stattab_value "${StatTabEntry__idrefs[$id]-}" || stttab_idrefs=$_
        ! stattab_value "${StatTabEntry__meta[$id]-}"   || stttab_meta=$_
      ;;
    .set-attr )
        $super.set-attr "${1:?}" "${2:-}" "${3:-StatTabEntry}" ;;
    .src )
      if_ok "$($self.srcspec)" && echo "${_/:*}" ;;
    .srcspec )
      if_ok "$($self.params)" && echo "${_/* }" ;;
    .tab ) $($self.tab-ref).tab ;;
    .tab-class )
      if_ok "$($self.tab-id)" && echo "$(class.Class Class $_ .class)" ;;
    .tab-id )
      $self.attr stattab ;;
    .tab-ref )
      if_ok "$($self.tab-id)" &&
      class.$(class.StatTabEntry StatTabEntry $_ .tab-class) $_ .tab-ref ;;
    .todotxt-field ) # ~ <Field-key>
        #local field=${1:?}
        #shift
        #todotxt_field_${field//-/_} <<< "$"
      ;;
    .toString )
        $self.set &&
        $self.entry
      ;;
    .update )
        $self.set &&
        stattab_update "$@" &&
        $self.get
      ;;
    .var ) # ~ <Var-key>             # Get field value from regular env variable
        : "stttab_${1//-/_}"
        echo "${!_}"
      ;;

    ( * ) return ${_E_next:?} ;;
  esac && return ${_E_done:?}
}


class_StatTab__load ()
{
  Class__static_type[StatTab]=StatTab:Class
  #ParameterizedClass
  declare -g -A StatTab__file=()
  declare -g -A StatTab__entry_type=()
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
        test -e "${2:-}" || {
            $LOG error :"${self}" "Tab file expected" "${2:-\$2:unset}:$#:$*" 1 || return
        }
        class_super_optional_call "$1" "${@:4}" || return
        StatTab__file[$id]=${2:?} &&
        StatTab__entry_type[$id]=${3:-StatTabEntry}
      ;;
    .__del__ )
        unset StatTab__file[$id] &&
        unset StatTab__entry_type[$id] &&
        ${super:?}.__del__
      ;;
    .count ) if_ok "$($self.tab-ref)" && wc -l "$_" ;;
    .exists ) # ~ <Id>
        stattab_exists "$1" "" "$($self.tab-ref)" ;;
    .fetch ) # ~ <Var-name> <Stat-id> [<Id-type>]
        : "${1:?Expected Var-name argument}"
        ! str_wordmatch "$1" self id super call ext class tab ||
          $LOG alert : "Cannot use reserved variable name" "$1" 1 || return
        : "${2:?Expected Stat-id argument}"
        $LOG debug : "Retrieving ${CLASS_NAME:?} entry" "$1=$2" &&
        if_ok "$($self.tab-ref)" &&
        stattab_fetch "$2" "${3:-}" "$_" ||
          $LOG error : "Fetching" "${3:-}${3:+:}$1=$2:E$?" $? || return
        # First process as StatTabEntry and then turn instance into IndexEntry
        create "$1" "StatTabEntry" "$id" "${stttab_lineno:?}" &&
        declare ref="${1#local:}" &&
        ${!ref:?Expected $ref}.get &&
        $LOG info :$id "Retrieved ${CLASS_NAME:?} entry" "$1=$2" ||
          $LOG error :$id "Retrieving ${CLASS_NAME:?} entry" "E$?:$stttab_id.$ext" $? || return
        declare ext class tab &&
        ext=$(${!ref}.attr meta:ext "" tab) &&
        class=$($self.tab-entry-class) &&
        tab=$(out_fmt= statusdir_lookup $stttab_id.$ext index) ||
          $LOG error :$id "No such index" "E$?:$stttab_id.$ext" $? || return
        ${!ref}.query-class "$1" "$class" &&
        ${!ref}.set-attr file "$tab" StatTab
      ;;
    .init ) local var=$1; shift
        stattab_init "$@" &&
        if_ok "$($self.tab-entry-class)" &&
        create "$var" "$_" "$id"
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
    .tab ) if_ok "$($self.tab-ref)" &&
      stattab_tab "${1:-}" "$_" ;;
    .tab-entry-class ) $self.attr entry_type StatTab ;;
    .tab-exists ) test -s "$($self.tab-ref)" ;;
    .tab-init ) stattab_tab_init "$($self.tab-ref)" ;;
    .tab-ref ) $self.attr file StatTab ;;

    ( * ) return ${_E_next:?} ;;
  esac && return ${_E_done:?}
}
