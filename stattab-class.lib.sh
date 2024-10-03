
stattab_class_lib__load ()
{
  ctx_class_types=${ctx_class_types-}${ctx_class_types:+" "}\
"StatDirIndex StatIndex StatTabEntry StatTab"
  : "${stattab_var_keys:=btime ctime id idrefs meta refs short status utime}"
}

stattab_class_lib__init () # ~
{
  test -z "${stattab_class_lib_init-}" || return $_
  lib_require stattab stattab-reader || return
  ! sys_debug -dev -debug -init ||
    $LOG notice "" "Loaded stattab-class.lib" "$(sys_debug_tag)"
}


class_StatDirIndex__load ()
{
  # about "StatTab file with lines representing stattab files in the statusdir/index folder" @StatDirIndex
  Class__static_type[StatDirIndex]=StatDirIndex:StatTab
  #uc_class_declare
}

class_StatDirIndex_ () # :StatTab (super,self,id,call) ~ <Call-args...>
{
  case "${call:?}" in

    ( .__init__ )
        $super.__init__ "${@:1:2}" "${3:-StatIndex}" "${@:4}" ;;

    ( .fetch-var ) # ~ <Var-name> <Stat-id> [<Id-type>]
        # First process as StatTabEntry and then turn instance into StatIndex
        # bc. we need to parse the stattab line to get attributes that determine
        # the actual file name to use as indextab.
        $super.fetch-var "$@" &&
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
  Class__static_type[StatTabEntry]=StatTabEntry:ParameterizedClass
  ctx_pclass_params=${ctx_pclass_params-}${ctx_pclass_params:+ }$stattab_var_keys

  declare -g -A StatTabEntry__btime=()
  declare -g -A StatTabEntry__ctime=()
  declare -g -A StatTabEntry__id=()
  declare -g -A StatTabEntry__idrefs=()
  declare -g -A StatTabEntry__meta=()
  declare -g -a StatTabEntry__meta_keys=()
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
        ${super:?}.__init__ "$1" "$2" "${@:4}" &&
        StatTabEntry__stattab[$id]=${2:?} &&
        StatTabEntry__seqidx[$id]=${3:?} &&
        local statfield &&
        for statfield in ${StatTab__statfields[$3]:-status btime ctime}
        do
          local -n __field="StatTabEntry__${statfield}[$id]"
          __field=-
        done &&
        #StatTabEntry__btime[$id]=- &&
        #StatTabEntry__ctime[$id]=- &&
        true
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

    .class-dump )
        $super.class-dump &&
        class_akdump StatTabEntry ${1:-\$OBJ_ID} stattab seqidx ${stattab_var_keys:?}
      ;;

    .commit )
      $self.set &&
      if_ok "$($self.tab-ref)" &&
        stattab_commit "$_" ;;

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
        ! stattab_value "${StatTabEntry__btime[$id]}"   || stab_btime=$_
        ! stattab_value "${StatTabEntry__ctime[$id]}"   || stab_ctime=$_
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

    .tab-class )
      if_ok "$($self.tab-id)" && echo "$(class.Class Class $_ .cparams)" ;;
    .tab-id )
      $self.attr stattab StatTabEntry ;;
    .tab-obj )
      if_ok "$($self.tab-class)" &&
      if_ok "$_ $_ $($self.tab-id)" &&
      echo "class.$_ " ;;
    .tab-ref )
      if_ok "$($self.tab-obj)" &&
      $_.tab-ref ;;

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
        stab_ctime="$(date '+%s')" &&
        if_ok "$($self.tab-ref)" &&
        stattab_commit "$_" &&
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
  Class__static_type[StatTab]=StatTab:CachedClass
  Class__rel_types[StatTab]=StatTabEntry,OS/FileStat,CachedClass
  # Map of object-id to stattab file path
  declare -gA StatTab__file=()
  # Can vary type per entry, set to default StatTabEntry on construction
  declare -gA StatTab__entry_type=()
  # Cache for entries holds <stattab-obj-id>,<entry-obj-id> to <entry-obj-ref>
  declare -gA StatTab__entry=()
  # Cache that maps entry-id to an cached entry-key
  declare -gA StatTab__entryid=()
  # Cache for OS/FileStat instances
  declare -gA StatTab__filestat=()
  declare -gA StatTab__statfields=()
}

# StatTab is a list of StatTabEntries, represented by a single file.
class_StatTab_ () # ~
#   .__init__ <ConcreteType> <Tab> [<EntryType>]         - constructor
#   .tab
#   .tab-exists
#   .tab-init
#   .exists <Entry-Id> <Type>
#   .init
#   .fetch <Entry-Id>
#   .fetch-var <Var-Name> <Entry-Id>
#   .update
#   .commit
{
  case "${call:?}" in

    .__init__ )
        [[ -e "${2-}" ]] || {
            $LOG error :"${self}" "Tab file expected" "${2:-\$2:unset}:$#:$*" 1 || return
        }
        # XXX: as long as there is no iface for 'unique', and static cache is
        # incomplete keep filepath in cparams for CachedClass to use
        class_super_optional_call "$1" "$2" "${@:4}" || return
        StatTab__file[$id]=${2:?} &&
        StatTab__entry_type[$id]=${3:-StatTabEntry}
      ;;

    .__cache__ ) # ~ ~ # Prepared cached entry

        declare tabf
        tabf=$($self.tab-ref) &&

        Std__cache[$tabf]=$tid
        Std__cache[$tabf:$eid]=$iid

        StatTab__entry[tid:iid]=eid
        [[ "$tabf" = "${StatTab__file[tid]}" ]] &&

        for field in $stattab_var_keys
        do
          stderr declare -p field
          StatTabEntry__${field:?}[$iid] || return
        done &&

        # cache is for this type (table), related entry types. dont care for
        # housekeeping in Class
        class.StatusDir --key var <<< "$*"
      ;;

    .__del__ )
        unset StatTab__file"[$id]" &&
        unset StatTab__entry_type"[$id]" &&
        ignore unset StatTab__entry"[$id]" &&
        ${super:?}.__del__
      ;;

    .assert )
        $self.init "$@" && $self.commit
      ;;

    .load ) ## Populate StatTab:entry (init entry type for all ids)
        # Iterate over ids (eid) and create entry objects (entry with oid)
        declare eid oid entry ids=()
        sys_execmap ids $self.ids &&
        for eid in "${ids[@]}"
        do
          $self.fetch "$eid" ||
            $LOG error : "Error fetching entry" E$?:$eid $? || return
        done
      ;;

    .__items__ )
        declare key oid
        for key in "${!StatTab__entry[@]}"
        do
          [[ $key =~ ^$id, ]] || continue
          #class.Class --ref ${oid}
          echo "${StatTab__entry["$key"]:?}"
        done
      ;;

    .class-dump )
        $super.class-dump &&
        arr_kdump StatTab__file "$id"  &&
        arr_kdump StatTab__entry_type "$id"  &&
        arr_kpdump StatTab__entryid "$id,"  &&
        { [[ ! ${StatTab__filestat[id]+set} ]] ||
          arr_kdump StatTab__filestat "$id" || return
        } &&
        arr_kpdump StatTab__entry "$id," &&
        local item &&
        local -a items &&
        sys_execmap items $self.__items__ &&
        for item in "${items[@]}"
        do
          ${item:?}.class-dump || return
        done
      ;;

    ( .check-fs ) TODO
      ;;

    .count ) if_ok "$($self.tab-ref)" && wc -l "$_" ;;

    .exists ) # ~ ~ <Id>
        local -n entryid="StatTab__entryid[\"${OBJ_ID:?},${1:?}\"]"
        [[ ${entryid+set} ]] || {
          if_ok "$($self.tab-ref)" &&
          stattab_exists "$1" "" "$_"
        }
      ;;

    .fetch ) # ~ ~ <Stat-id> [<Id-type>]
        local -n entryid="StatTab__entryid[\"${OBJ_ID:?},${1:?}\"]"
        [[ ${entryid+set} ]] && {
          $self.check-fs
          # entry=$(class.Class --ref $entryid)
        } || {
          # Cannot store directly at cache array without having instance Id
          local entry
          $self.fetch-var entry "${@:?}" &&
          $self:stattab:cache:set "${1:?}" "$entry"
        }
      ;;

    .fetch-var ) # ~ ~ <Var-name> <Stat-id> [<Id-type>]
        ! str_wordmatch "$1" self id super call ext class tab ||
          $LOG alert "" "Cannot use reserved variable name" "$1" 1 || return
        $LOG debug "" "Retrieving ${CLASS_NAME:?} entry" "$1=$2${3+:}${3-}" &&
        $self:stattab:entry:fetch "${@:2}" &&
        $self:stattab:entry:newobj "${1:?}"
      ;;


    /filestat ) # ~ ~
        : about "Create FileStat instance"
        : extended "Instance is created if missing"
        local filestat_v="StatTab__filestat[\"$OBJ_ID\"]"
        local -n __filestat="$filestat_v"
        [[ "${__filestat+set}" ]] || {
          local tabf
          tabf=$($self.tab-ref) &&
          class_new __filestat OS/FileStat "$tabf" || return
        }
      ;;

# This does a cached access to /filestat
# not sure if that is useful here, but in itself its a useful pattern to
# explore and work out for speeding up more serious work.

    ( :filestat ) # ~ ~ [<Var>]
        local dirty tabf
        $self:filestat+fromcache || {
          stderr echo $SELF_NAME:filestat cache miss
          $self/filestat &&
          dirty=true || return
        }
        $self:filestat+env || return
        stderr script_debug_arrs StatTab__filestat
        stderr script_debug_vars filestat
        stderr echo filestat=$filestat
        $filestat.refresh os-filestat || return
        ! "${dirty:-false}" || {
          $filestat.commit-cache
        }
      ;;

    ( :filestat+fromcache ) # ~ ~ [<Var>]
        tabf=$($self.tab-ref) &&
        class.CachedClass --get-from-cache "$tabf" filestat os-filestat
        #class.OS-FileStat --get-from-cache-old filestat "$tabf" "${CACHE_DIR:?}/os-filestat.sh"
      ;;

    ( :filestat+env ) # ~ ~ [<Var>]
        local -n __filestat=${1:-filestat}
        __filestat="${StatTab__filestat["$OBJ_ID"]}"
        return

        local filestat_v="StatTab__filestat[\"$OBJ_ID\"]" &&
        # TODO: refresh on TTL
        #local -n __filestat="$filestat_v" &&
        #${__filestat:?}.class-dump &&
        case "${1-}" in
          local:* )
              eval "${1#local:}=$filestat_v"
            ;;
          * ) declare -gn "${1:-filestat}=$filestat_v" ;;
        esac
      ;;

    .keys|.list ) # ~ ~ [<Key-match>]
        stderr echo "Deprecated: call=$call from $(caller 1) (use .ids)"
        $self.ids "$@"
      ;;

    .ids ) # ~ ~ [<Key-match>]
        stattab_list "${1-}" "$($self.tab-ref)"
      ;;

    .init ) # ~ ~ <Stat-id> <Entry...> # Wrap exists/new or fetch in one call, but do not commit
        # See also .assert
        $self.exists "${1:?}" && {
          $self.fetch "${1:?}" || return
        } || {
          $self.new "${@:?}"
        }
      ;;

    .init-var ) # ~ ~ <Var> <Entry...> #
        $self.exists-var "${1:?}" "${2:?}" && {
          $self.fetch-var "${1:?}" "${2:?}" || return
        } || {
          $self.new-var "${@:?}"
        }
      ;;

    .new ) # ~ ~ <Stat-id> [<Rest...>] # Create entry from id and label+annotation
        local entry
        $self.new-var entry "${@:?}" &&
        $self:stattab:cache:set "${1:?}" "$entry"
      ;;

    .new-var ) # ~ ~ <Var> <Stat-id> [<Rest..>] # Create entry from id and label+annotation
        # New but bypass stattab:entry cache
        $self:stattab:entry:init "${@:2}" &&
        $self:stattab:entry:newobj "${1:?}"
      ;;

    .new-with ) # ~ ~ <Id> <Entry-type> [<Rest..>]
        TODO "may want custom entry type per entry"
      ;;

    .new-direct ) # ~ ~ <Id> [<Rest>] # Create entry from id and label+annotation
        local tbref dtnow
        tbref="$($self.tab-ref)" &&
        dtnow="$(date_id $(date --iso=min))" &&
        echo "- $dtnow $1:${2:+ }${2-}" >> "$tbref"
      ;;

    .tab ) # ~ <> ... # Output table data from file
        if_ok "$($self.tab-ref)" &&
        stattab_tab "${1-}" "$_" ;;

    .tab-entry-class ) $self.attr entry_type StatTab ;;
    .tab-exists ) [[ -s "$($self.tab-ref)" ]] ;;
    .tab-init ) stattab_tab_init "$($self.tab-ref)" ;;
    .tab-ref ) $self.attr file StatTab ;;
    .tab-status ) # ~ [<>]
        # XXX: refresh status context_run_hook stat || return
        #local entry status
        $self.fetch-var local:entry "$1" &&
          [[ "${entry-}" ]] || return ${_E_NF:?}
        status=$($entry.attr status) &&
        [[ "$status" ]] &&
        ! fnmatch "[${stb_pri_sep:?}]" "$_" && {
          [[ 0 = "$_" ]] ||
          fnmatch "*[${stb_pri_sep:?}]0" "$_"
        }
      ;;


    --find-cache ) # ~ ~ <StatTab-file>
        # Override class.CachedClass --find-cache
        local oid &&
        for oid in "${!StatTab__file[@]}"
        do
          [[ ${StatTab__file[$oid]} = "${1:?}" ]] || continue
          echo "$oid"
        done

      ;;

    # FIXME: remove after proper static uc-class impl.
    --load-from-cache-old ) # ~ ~ <Obj-ref> <StatTab-file> <Stattab-sh-cache-file>
        . "${3:?}" &&
        local -n __obj=${1:?} &&
        local oid &&
        for oid in "${!StatTab__file[@]}"
        do
          [[ ${StatTab__file[$oid]} = "${2:?}" ]] || continue
          __obj=$(class.Class --ref $oid) ||
            test 200 -eq $? || return $_
          return
        done
      ;;


    :stattab:cache:set )
        : "${1:?Expected entry-id argument}"
        : "${2:?Expected entry-instance-reference argument}"
        local entryid=${1:?} entryref=${2:?}
        # Extract object Id of entry
        : "${entryref% }" &&
        : "${_##* }" &&
        local -i oid=${_:?} &&
        # Store ref
        declare -g "StatTab__entry[\"${OBJ_ID:?},$oid\"]=$entryref"
        #! [[ ${2:-} = ]] ||
        declare -g "StatTab__entryid[\"${OBJ_ID:?},${entryid:?}\"]"=${oid}
      ;;

    :stattab:entry:fetch )
        : "${1:?Expected Stat-id argument}"
        if_ok "$($self.tab-ref)" &&
        stattab_fetch "$1" "${2-}" "$_"
      ;;

    :stattab:entry:init )
        : "${1:?Expected Stat-id argument}"
        # Create from record (without stat), add minimal stat descriptor
        local tbref dtnow
        tbref="$($self.tab-ref)" &&
        dtnow="$(date_id $(date --iso=min))" &&
        stattab_entry_init "- $dtnow ${1:?}:${2:+ }${2-}"
      ;;

    :stattab:entry:newobj )
        : "${1:?Expected var name argument}"
        typeset -n __fetch_obj=${1#local:}
        if_ok "$($self.tab-entry-class)" &&
        class_new "$1" "$_" "$id" "${stab_lineno:--}" &&
        ${__fetch_obj:?}.get
      ;;


    -init ) # ~ var tab entry
        declare tab=${2:?}
        declare -n var=${1:?}
        class_init "${3:-StatTabEntry}" &&
        class_new $1 StatTab "$tab"
      ;;

    * ) return ${_E_next:?}
  esac && return ${_E_done:?}
}
