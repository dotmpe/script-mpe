
stattab_reader_lib__load ()
{
  lib_require date-htd match-htd str-htd todotxt || return
  : "${stb_pri_sep:=/:,.+-}"
  : "${stb_stat_xr:=\/:,\.+-}" # Extra characters for stat fields (RE format)
  : "${stb_id_xr:=\/:$%&@_\.+-}" # Extra characters for id field (RE format)
}


# Assuming entry is updated replace or add to Stat-Tab
stattab_commit () # ~ [<Stat-Tab>]
{
  test -n "${1-}" || set -- $STTAB
  stattab_exists "" "" "$1" && {

# XXX: observe different Id types in replace as well like in grep, probably..
    local p_=$stttab_id
    #$(match_grep "$stttab_id")
    $gsed -i 's/^[0-9 +-]* '$p_':.*$/'"$(stattab_entry)"'/' "$1"
    return
  } || {
    stattab_entry >>"$1"
  }
}

# Parse date-id
stattab_date ()
{
  fnmatch "@*" "$1" && echo "${1:2}" || date_pstat "$1"
}

stattab_entry () #
{
  if_ok "$(stattab_print_STD_stat)" || return
  # FIXME?
  #echo "$_ $stttab_id: $stttab_short $stttab_tags" | sh_normalize_ws
  : "$_ $stttab_id: $stttab_short $stttab_tags $stttab_refs $stttab_idrefs"
  echo ${_//[$'\n\t']/ }
  #echo "${_//  / }"
}

stattab_print_STD_stat ()
{
  #! "${stttab_closed}" || echo "# "
  ! stattab_value "${stttab_status-}" || echo "$_"
  date_id "@$stttab_btime"
  date_id "@$stttab_ctime"
  ! stattab_value "${stttab_utime-}" || date_id "@$stttab_utime"
  ! stattab_value "${stttab_directives-}" || echo "$_"
  ! stattab_value "${stttab_passed-}" || echo "$_"
  ! stattab_value "${stttab_skipped-}" || echo "$_"
  ! stattab_value "${stttab_erred-}" || echo "$_"
  ! stattab_value "${stttab_failed-}" || echo "$_"
}

stattab_entry_id () # ~ <StatTab-SId> [<StatTab-Id>]
{
  test $# -gt 1 || {
    if_ok "$(mkid "$1" && printf "$id")" || return
    set -- "$1" "$_"
  }
  stttab_sid="$1"
  stttab_id="$2"
}

stattab_entry_id_valid ()
{
  [[ "$sttab_id" =~ /^[A-Za-z_][A-Za-z0-9_-]*$/ ]]
}

stattab_entry_init () # ~ [<Entry>]
{
  stattab_entry_env_reset
  stttab_entry="$*"
  stattab_entry_parse &&

  echo "$stttab_id" | grep -q '^[A-Za-z_][A-Za-z0-9_-]*$' ||
      error "Illegal ST name '$stttab_id'" 1
}

stattab_entry_env_reset ()
{
  stttab_status=
  stttab_btime=
  stttab_ctime=
  stttab_utime=
  stttab_directives=
  stttab_passed=
  stttab_skipped=
  stttab_erred=
  stttab_failed=
  stttab_sid=
  stttab_short=
  stttab_refs=
  stttab_idspec=
  stttab_idrefs=
  stttab_meta=
  stttab_tags_raw=
  stttab_tags=

  stttab_lineno=
  stttab_entry=
  stttab_stat=
  stttab_record=
  stttab_rest=
  stttab_id=
  stttab_primctx=
  stttab_primctx_id=
}

stattab_entry_defaults () # ~
{
  local now="$(date +'%s')"
  stattab_value "${stttab_btime:-}" || stttab_btime=$now
  stattab_value "${stttab_ctime:-}" || stttab_ctime=$now
}

# Parse statusdir index file line
stattab_entry_parse () # [entry] ~
{
  test $# -eq 0 || return ${_E_GAE:?}
  # Split rest into three parts (see stattab format), first stat descriptor part
  stttab_record=$(str_globstripcl "${stttab_entry:?}" "[0-9 $stb_pri_sep]")
  stttab_stat=${stttab_entry:0:$(( ${#stttab_entry} - ${#stttab_record} - 1 ))}
  $LOG debug : "Parsing descriptor and record" "'$stttab_stat':'$stttab_record'"
  stattab_parse_STD_stat $stttab_stat &&
  stattab_record_parse
}

stattab_entry_pri ()
{
  false
}

stattab_exists () # [<Stat-Id>] [<Entry-Type>] [<Stat-Tab>]
{
  grep_f=${grep_f:-"-q"} \
    stattab_grep "${1:-$stttab_id}" "${2:-"id"}" "${3:-$STTAB}"
}

# Retrieve and parse entry from table
stattab_fetch () # ~ [<Stat-Id>] [<Search-Type>] [<Stat-Tab>]
{
  test -n "${1:-"${stttab_id:-}"}" || return ${_E_GAE:?}
  set -- "$_" "${2:-"id"}" "${3:-"$STTAB"}"
  stttab_src=${3:?}
  if_ok "$(grep_f="-m1 -n" stattab_grep "$@")" &&
  stattab_parse "$_"
}

# Helper for other stattab-base; runs stattab-act on every parsed entry
stattab_foreach () # <Stat-Id> [<Tags>]
{
  test -n "${sttab_act:-}" || return 90
  test "unset" != "${sttab_base-"unset"}" || local sttab_base=sttab
  ${sttab_base}_fetch "$@" | {
      local r=
      while read -r stattab_line
      do
        ${sttab_base}_entry_parse "_:${stattab_line}" || return
        ${sttab_base}_parse_STD_stat $stat || return
        $sttab_act || return
      done
      return $r
  }
}

# Take tab output and perform some sort of grep
stattab_grep () # ~ <Sttab-Id> [<Search-Type>] [<Stat-Tab>]
{
  test $# -ge 1 -a -n "${1-}" -a $# -le 3 || return ${_E_GAE:?}
  test ! -t 0 || {
    test -n "${stb_fp-}" && {
      exec < "$stb_fp" || return
    } || {
      : "${stb_gen:=stattab_tab}"
      stb_gl="$($_ "" "${3-}")" || ignore_sigpipe || return
      exec <<< "$stb_gl" || return
    }
  }

  test "unset" != "${grep_f-"unset"}" || local grep_f=-m1
  local act=${2:-} st_ p_; match_grep_arg "$1"
  act=${act:+$(str_globstripcl "${act:?}" -)}
  : "${act:=local}"
  st_="^[$STTAB_FS$STTAB_STATC]*"
  case "${act}" in
    alias|ids )
        $ggrep $grep_f "$st_\\([^:]*:$p_:\\?\\|.* alias:$p_\\)\\(\\ \\|\$\\)"
      ;;
    any )
        $ggrep $grep_f "$st_.*$p_" ;;
    full )
        $ggrep $grep_f "$p_" ;;
    id )
        #$ggrep $grep_f "$st_\\b$p_:\\?\\(\\ \\|\$\\)" ;;
        $ggrep $grep_f "^[0-9 ${stb_pri_sep:?}]* $p_:\\?\\(\\ \\|\$\\)" ;;
    local )
        $ggrep $grep_f "${st_}[^:]*:$p_:\?\(\\ \|\$\)" ;;
    ref ) todotxt_grep_ ref ;;
    sub )
        $ggrep $grep_f "${st_}[^ ]*\/$p_:\?\(\\ \|\$\)" ;;
    tag|ns-id )
        test -n "${NS:-}" || local NS=${CTX_DEF_NS:?}
        $ggrep $grep_f "$st_\b\\($NS:\\)\\?$p_\\(:\\(\\ \\|$\\)\\| \\)" ;;
    tagged )
        $ggrep $grep_f "${st_}[^: ]*:\? .* \(\+\|@\)$p_\( \|\$\)" ;;
# XXX: is this correct, it messes up my syntax highlighting
    #literalid )
    #    $ggrep $grep_f "^[0-9 +-]* [^:]*:\?\( .*\)\? ``'$p_\`\`\( \|\$\)" ;;
    word )
        $ggrep $grep_f "\\(^\\|[$STTAB_FS]\\)$p_\\([$STTAB_FS]\\|\$\\)" ;;

    ( * ) $LOG error : "No such search-type" "$act" ${_E_nsa:?} ;;
  esac
}


stattab_ids ()
{
  $gsed -E \
    's/^[0-9 '"${stb_stat_xr}"']+ ([A-Za-z0-9 '"${stb_id_xr}"']+):( *| .*)$/\1/'
}

# Parse Entry or set all defaults
stattab_init () # ~ [<Entry>]
{
  stattab_entry_env_reset && {
    test $# -eq 0 || {
      stattab_entry_init "$@" && shift
  } } && stattab_entry_defaults
}

stattab_tab_init () # ~ [<Stat-Tab>]
{
  test $# -le 1 || return 177
  test -n "${1-}" || set -- "$STTAB"
  test -s "$1" && return
  mkdir -vp "$(dirname "$1")" &&
  { cat <<EOM
# [Status] [BTime] CTime UTime [Dirs Pass Skip Err Fail Tot] Name-Id: Short @Ctx +Proj
# Id: _CONF                                                        ex:ft=todo:
EOM
} >"$1"
}

# List ST-Id's only from tab output
stattab_list () # ~ [<Match-Line>] [<Stat-Tab>]
{
  stattab_tab "$@" | stattab_ids
}

stattab_list_field_ () # ~
{
  local field=${1:?}; shift;
  read_nix_style_file "$@" | todotxt_field_${field//-/_}
}

stattab_list_ () # ~ ( context-tags | chevron-refs | meta-tags | hash-tags | project-tags )
{
  local field=${1:?}; shift;
  stattab_tab "$@" | todotxt_field_${field//-/_}
}

# Parse entry from Grep-line (with line number)
stattab_parse () # ~ <Grep-line>
{
  test $# -gt 0 || return ${_E_MA:?}
  stattab_entry_env_reset
  # XXX: Merge line (ie. normalize ws?)
  set -- "$*"
  test -n "$1" || return 0
  # Remove grep-line filename/linenumber from entry and parse
  stttab_lineno=${1%%:*}
  stttab_entry=${1#*:}
  stattab_entry_parse ||
    $LOG error :stattab-parse "Parsing entry" "E$?:L$stttab_lineno:$stttab_src" $?
}

# XXX: set for dynamic (id) context
stattab_meta_parse () # ~ <Arr-var-pref>
{
  sh_arr "$1"_keys || return ${_E_GAE:?}
  typeset metatag metakey metaval
  typeset -a keys
  for metatag in $stttab_meta
  do
    metakey=${metatag%:*}
    keys+=( "$metakey" )
    metaval=${metatag##*:}
    : "${metakey//:/__}"
    : "${metakey//-/_}"
    declare -g "$1__${_}[$id]=$metaval"
  done
  declare -g "$1_keys[$id]=${keys[*]}"
}

stattab_meta_unset () # (id) ~
{
  declare key
  for key in StatTabEntry__meta_keys[$id]
  do
    : "${key//:/__}"
    : "${key//-/_}"
    unset StatTabEntry__meta__${_}
  done &&
  unset StatTabEntry__meta_keys[$id]
}

stattab_parse_STD_ids ()
{
  test -z "${1-}" || stattab_entry_id "$1"
}

stattab_parse_STD_stat () # ~ [Status] [BTime] [CTime] [UTime] [Dirs] [Passed] [Skipped] [Error] [Failed]
{
  ! stattab_value "${1-}" || stttab_status=$1
  ! stattab_value "${2-}" || stttab_btime="$(stattab_date "$2")"
  ! stattab_value "${3-}" || stttab_ctime="$(stattab_date "$3")"
  ! stattab_value "${4-}" || stttab_utime="$(stattab_date "$4")"
  ! stattab_value "${5-}" || stttab_directives=$5
  ! stattab_value "${6-}" || stttab_passed=$6
  ! stattab_value "${7-}" || stttab_skipped=$7
  ! stattab_value "${8-}" || stttab_erred=$8
  ! stattab_value "${9-}" || stttab_failed=$9
  test 9 -ge $# ||
    $LOG warn :stb-parse:Std:stat "Surplus fields on record"
}

# Set to new given entry and add it to table directly
stattab_record () # ~ <Entry>
{
  test $# -gt 0 || return ${_E_MA:?}
  test -n "$*" || return ${_E_GAE:?}
  stattab_entry_init "$@" &&
  stattab_entry_defaults &&
  # XXX: stattab_entry >>"$1"
  stattab_commit >>"$1"
}

stattab_record_parse () # (sttab_record) ~
{
  # stattab_parse ID_SPEC TAGS META SHORT

  # TODO parse using glob specs
  stttab_idspec=${stttab_record%%:*}
  stattab_parse_STD_ids $stttab_idspec

  stttab_rest="$(echo "$stttab_record"|cut -d : --output-delimiter : -f2-)"
  # XXX: Stop short description at first tag?
  stttab_short="$(echo "$stttab_rest"|$gsed 's/^\([^[+@<]*\).*$/\1/'|normalize_ws)"

  stttab_refs="$(todotxt_field_chevron_refs <<< "$stttab_rest")"
  stttab_idrefs="$(todotxt_field_hash_tags <<< "$stttab_rest")"
  stttab_meta="$(todotxt_field_meta_tags <<< "$stttab_rest")"

  # FIXME: seems like an old regex
  stttab_tags_raw="$(echo "$stttab_rest"|$gsed 's/^[^\[+@<]*//'|normalize_ws)"
  stttab_tags="$(todotxt_field_context_tags <<< "$stttab_tags_raw")"

  true
}

# List entries; first argument is glob, converted to (grep) line-regex.
# FIXME: combine read-nix regex with match-glob
stattab_tab () # ~ [<Match-Line>] [<Stat-Tab>]
{
  test -n "${2-}" || set -- "${1-}" "$STTAB"
  test "$1" != "*" || set -- "" "$2"
  test -n "$1" && {
    test -n "${grep_f-}" || local grep_f=-P
    if_ok "$(compile_glob "$1")" &&
    $ggrep $grep_f "$_" "$2" || return
  } || {
    read_nix_style_file "$2" || return
  }
}

stattab_update () # ~ <Entry>
{
      stttab_status="${1:-"${new_tab_status:-"$stttab_status"}"}"
       stttab_btime="${2:-"${new_tab_btime:-"$stttab_btime"}"}"
       stttab_ctime="${3:-"${new_tab_ctime:-"$stttab_ctime"}"}"
       stttab_utime="${4:-"${new_tab_utime:-"$stttab_utime"}"}"
  stttab_directives="${5:-"${new_tab_directives:-"$stttab_directives"}"}"
      stttab_passed="${6:-"${new_tab_passed:-"$stttab_passed"}"}"
     stttab_skipped="${7:-"${new_tab_skipped:-"$stttab_skipped"}"}"
       stttab_erred="${8:-"${new_tab_erred:-"$stttab_erred"}"}"
      stttab_failed="${9:-"${new_tab_failed:-"$stttab_failed"}"}"

  # XXX: the id can be updated as well, may want to check wether new VId==Id
         stttab_id="${10:-"${new_tab_id:-"$stttab_id"}"}"
  # XXX: these may have whitespace and need to be quoted, or change this to wark
  # like parser.
      stttab_short="${11:-"${new_tab_short:-"$stttab_short"}"}"
       stttab_tags="${12:-"${new_tab_tags:-"$stttab_tags"}"}"
}

stattab_value () # ~ <Value>
{
  test -n "${1-}" -a "${1-}" != "-"
}
