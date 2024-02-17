
stattab_class_lib__load ()
{
  ctx_class_types=${ctx_class_types-}${ctx_class_types:+" "}\
"StatDirIndex StatIndex StatTabEntry StatTab"
  : "${stattab_var_keys:=btime ctime id idrefs meta refs short status utime}"
}

stattab_class_lib__init () # ~
{
  test -z "${stattab_class_lib_init-}" || return $_
  lib_require stattab stattab-reader
}


class_StatDirIndex__load ()
{
  # about "StatTab file with lines representing stattab files in the statusdir/index folder" @StatDirIndex
  Class__static_type[StatDirIndex]=StatDirIndex:StatTab
}

class_StatDirIndex_ () # :StatTab (super,self,id,call) ~ <Call-args...>
{
  case "${call:?}" in

    ( .__init__ )
        $super.__init__ "${@:1:2}" "${3:-StatIndex}" "${@:4}" ;;

    ( .fetch ) # ~ <Var-name> <Stat-id> [<Id-type>]
        # First process as StatTabEntry and then turn instance into StatIndex
        # bc. we need to parse the stattab line to get attributes that determine
        # the actual file name to use as indextab.
        $super.fetch "$@" &&
        declare ref="${1#local:}" &&
        ${!ref:?Expected $1 reference}.get &&
        $LOG notice :$id "Retrieved ${CLASS_NAME:?} entry" "$1=$2" || return
        declare ext class tab &&
        ext=$(${!ref}.attr meta:ext "" tab) &&
        class=$($self.tab-entry-class) &&
        tab=$(out_fmt= statusdir_lookup $stab_id.$ext index) ||
          $LOG error :$id "No such index" "E$?:$stab_id.$ext" $? || return
        ${!ref}.switch-class "$1" "$class" &&
        ${!ref}.set-attr file "$tab" StatTab
      ;;

      * ) return ${_E_next:?}
  esac && return ${_E_done:?}
}


class_StatIndex__load ()
{
  : about "Line in StatDirIndex representing another StatTab file" @StatIndex
  Class__static_type[StatIndex]=StatIndex:StatTabEntry:StatTab
}

class_StatIndex_ () # (super,self,id,call) ~ <Call ...>
{
  case "${call:?}" in
      * ) return ${_E_next:?}
  esac && return ${_E_done:?}
}


class_StatTabEntry__load () # ~
{
  : about "Entry in StatTab file" @StatTabEntry
  Class__static_type[StatTabEntry]=StatTabEntry:Class
  ctx_pclass_params=${ctx_pclass_params-}${ctx_pclass_params:+ }$stattab_var_keys
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

class_StatTabEntry_ () # :Class (super,self,id,call) ~ <ARGS...>
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
        $super.attr "$1" "${2:-StatTabEntry}" ${3-} ;;

    .commit ) $self.set &&
        stattab_commit $($($self.tab).tab-ref) ;;

    .entry ) stattab_entry ;;

    .get ) # ~ ~ # Move static (stab_*) vars onto class context
        StatTabEntry__status[$id]=$stab_status
        StatTabEntry__btime[$id]=$stab_btime
        StatTabEntry__ctime[$id]=$stab_ctime
        StatTabEntry__utime[$id]=$stab_utime
        StatTabEntry__id[$id]=$stab_id
        StatTabEntry__short[$id]=$stab_short
        StatTabEntry__tags[$id]=$stab_tags
        StatTabEntry__refs[$id]=$stab_refs
        StatTabEntry__idrefs[$id]=$stab_idrefs
        stattab_meta_parse StatTabEntry__meta
      ;;
    .line )
      if_ok "$($self.srcspec)" && echo "${_/*:}" ;;

    .set )
        ! stattab_value "${StatTabEntry__status[$id]-}" || stab_status=$_
        ! stattab_value "${StatTabEntry__btime[$id]}"  || stab_btime=$_
        ! stattab_value "${StatTabEntry__ctime[$id]}"  || stab_ctime=$_
        ! stattab_value "${StatTabEntry__utime[$id]-}"  || stab_utime=$_
        ! stattab_value "${StatTabEntry__id[$id]-}"     || stab_id=$_
        ! stattab_value "${StatTabEntry__short[$id]-}"  || stab_short=$_
        ! stattab_value "${StatTabEntry__tags[$id]-}"   || stab_tags=$_
        ! stattab_value "${StatTabEntry__refs[$id]-}"   || stab_refs=$_
        ! stattab_value "${StatTabEntry__idrefs[$id]-}" || stab_idrefs=$_
        ! stattab_value "${StatTabEntry__meta[$id]-}"   || stab_meta=$_
      ;;
    .set-attr )
        $super.set-attr "${1:?}" "${2-}" "${3:-StatTabEntry}" ;;
    .src )
        if_ok "$($self.srcspec)" && echo "${_/:*}" ;;
    .srcspec )
        if_ok "$($self.params)" && echo "${_/* }" ;;

    .status ) # ~ [<>]
      ;;

    .tab ) $($self.tab-ref).tab ;;

    .tab-class )
      if_ok "$($self.tab-id)" && echo "$(class.Class Class $_ .class)" ;;
    .tab-id )
      $self.attr stattab ;;
    .tab-ref )
      if_ok "$($self.tab-id)" &&
      if_ok "$(class.StatTabEntry StatTabEntry $_ .tab-class) $_" &&
      class.$_ .tab-ref ;;
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
        : "stab_${1//-/_}"
        echo "${!_}"
      ;;

    ( * ) return ${_E_next:?}
  esac && return ${_E_done:?}
}


class_StatTab__load ()
{
  : about "File with lines or blocks representing entries consisting of status and description fields for some entity" @StatTab
  Class__static_type[StatTab]=StatTab:Class
  Class__rel_types[StatTab]=StatTabEntry
  declare -gA StatTab__file=()
  declare -gA StatTab__entry_type=()
  declare -gA StatTab__entry=()
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

    -init ) # ~ var tab entry
        declare tab=${2:?}
        declare -n var=${1:?}
        class_init "${3:-StatTabEntry}" &&
        class_new $1 StatTab "$tab"
      ;;

    .__init__ )
        test -e "${2-}" || {
            $LOG error :"${self}" "Tab file expected" "${2:-\$2:unset}:$#:$*" 1 || return
        }
        class_super_optional_call "$1" "${@:4}" || return
        StatTab__file[$id]=${2:?} &&
        StatTab__entry_type[$id]=${3:-StatTabEntry}
      ;;

    .__del__ )
        unset StatTab__file"[$id]" &&
        unset StatTab__entry_type"[$id]" &&
        ignore unset StatTab__entry"[$id]" &&
        ${super:?}.__del__
      ;;

    .__cache__ )
        declare tabf
        tabf=$($self.tab-ref) &&

        Std__cache[$tabf]=$tid
        Std__cache[$tabf:$eid]=$iid

        StatTab__entry[tid:iid]=eid
        test "$tabf" = "${StatTab__file[tid]}"

        for field in $stattab_var_keys
        do
          StatTabEntry__*[$iid]
        done

        # cache is for this type (table), related entry types. dont care for
        # housekeeping in Class
        class.StatusDir --key var <<< "$*"
      ;;

    .__items__ )
        declare eid oid entry ids=()
        sys_arr ids $self.list &&
        for eid in "${ids[@]}"
        do
          $self.fetch local:entry "$eid" || return
          : "${entry% }"
          : "${_##* }"
          oid=$_
          declare -g "StatTab__entry[$id:$oid]"=$eid
          #$eid
          $entry.toString
        done
      ;;

    .count ) if_ok "$($self.tab-ref)" && wc -l "$_" ;;

    .exists ) # ~ ~ <Id>
        if_ok "$($self.tab-ref)" &&
        stattab_exists "$1" "" "$_"
      ;;

    .fetch ) # ~ ~ <Var-name> <Stat-id> [<Id-type>]
        : "${1:?Expected Var-name argument}"
        ! str_wordmatch "$1" self id super call ext class tab ||
          $LOG alert "" "Cannot use reserved variable name" "$1" 1 || return

        : "${2:?Expected Stat-id argument}"
        $LOG debug "" "Retrieving ${CLASS_NAME:?} entry" "$1=$2" &&
        if_ok "$($self.tab-ref)" &&

        stattab_fetch "$2" "${3-}" "$_" ||
          $LOG error "" "Failed fetching" "${3-}${3:+:}$1=$2:E$?" $? || return

        typeset -n obj=${1#local:}
        class_new "$1" "StatTabEntry" "$id" "${stab_lineno:?}" &&
        $obj.get
      ;;

    .init ) # ~ ~ <Entry> # Create entry instance from given
        local var=$1; shift
        stattab_init "$@" &&
        if_ok "$($self.tab-entry-class)" &&
        create "$var" "$_" "$id"
      ;;

    .list|.ids|.keys ) # ~ ~ [<Key-match>]
        stattab_list "${1-}" "$($self.tab-ref)"
      ;;

    .new ) # ~ ~ <Id> [<Rest>]
        local tbref dtnow
        tbref="$($self.tab-ref)" &&
        dtnow="$(date_id $(date --iso=min))" &&
        echo "- $dtnow $1:${2:+ }${2-}" >> "$tbref"
      ;;

    .tab ) if_ok "$($self.tab-ref)" &&
        stattab_tab "${1-}" "$_" ;;
    .tab-entry-class ) $self.attr entry_type StatTab ;;
    .tab-exists ) test -s "$($self.tab-ref)" ;;
    .tab-init ) stattab_tab_init "$($self.tab-ref)" ;;
    .tab-ref ) $self.attr file StatTab ;;
    .tab-status ) # ~ [<>]
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

      * ) return ${_E_next:?}
  esac && return ${_E_done:?}
}
