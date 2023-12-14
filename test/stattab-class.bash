sh_mode strict
scriptname=$(basename "$0" .sh)

lib_load lib-uc
lib_init lib-uc
uc_script_load user-script
sh_fun user_script_initlibs
user_script_initlibs script-mpe shell

lib_uc_load stattab-class
sh_fun stattab_class_lib__load
sh_fun stattab_class_lib__init
if_ok "$(user_script_initlibs__needsinit stattab-class)"
test "$_" = "stattab-class"

user_script_initlibs stattab-class &&
test "${lib_loaded:?}" = "lib-uc script-mpe os sys str log shell stdlog-uc"\
" date date-htd stattab-class argv-uc sys-htd os-htd statusdir stattab match"\
" match-htd str-htd todotxt-fields stattab-reader" ||
  $LOG error : "1.1" "$lib_loaded" $?

$LOG notice : "Loaded, starting tests"
test "${STIDX:?}" = "${STATUSDIR_ROOT:?}index/${STIDX_NAME:-index.tab}"
test "${STTAB:?}" = "${STATUSDIR_ROOT:?}index/${STTAB_NAME:-stattab.list}"

user_script_initlibs class-uc &&

create indextabs StatTab "$STIDX" IndexEntry
STDIDX_ID=$($indextabs.id)
if_ok "$($indextabs.attr file StatTab)"
test "$_" = "$STIDX"

for index_sid in $($indextabs.keys)
do
  $indextabs.fetch index "$index_sid" ||
    stderr echo fetch failed sid=$index_sid E$? ref=index=$index
  test -z "$index" || {
    #echo "Table file: $($index.attr stattab StatTabEntry)"
    #echo "Table row: $($index.attr seqidx StatTabEntry)"
    $index.entry && destroy index
  }
done

script_debug_arrs \
  Class__{type,instance} \
  StatTab__{file,entry_type} \
  StatTabEntry__{stattab,seqidx}

#
