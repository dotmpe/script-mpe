#!/bin/sh

# Status-Table-Id: stattab
# -Var: sttab/STTAB

stattab_lib__load ()
{
  lib_assert statusdir || return
  test -n "${STTAB-}" || STTAB=$(out_fmt= statusdir_lookup stattab.list index)
}

stattab_lib__init ()
{
  return # XXX:

  test -n "${STTAB-}" || {
    $LOG error "stattab.lib:init" "Expected STTAB" "$STTAB"
    return 1
  }
  test -e "$STTAB" || {
    test ${init:-0} -eq 0 && {
        $LOG error "stattab.lib:init" "Expected existing STTAB" "$STTAB"
        return 1
      }
    mkdir -p "$(dirname "$STTAB")" && touch "$STTAB" || return
  }
  sttab_id=
}


# Get lines to initial stat descr for
stattab_descr () #
{
  test -n "$sttab_status" || sttab_status=-
  test -n "$sttab_ctime" || sttab_ctime=$( date +"%s" )
  echo "$sttab_status"
  date_id "$sttab_ctime"
}

# Prepare env for Stat-Id
stattab_env_init () # [stattab] ~ [St]
{
  stattab_entry_env_reset &&
  stattab_entry_init "$1" && {
    test -z "$1" || shift
  } # XXX: && stattab_entry_defaults "$@"
}

stattab_entry_init () # STVID [STID]
{
  sttab_id="$1"
  echo "$sttab_id" | grep -q '^[A-Za-z_][A-Za-z0-9_-]*$' ||
      error "Illegal ST name '$sttab_id'" 1
}

stattab_entry_update ()
{
  test -z "$new_status" || sttab_status="$new_status"
  test -z "$new_ctime" || sttab_ctime="$new_ctime"
  test -z "$new_mtime" || sttab_mtime="$new_mtime"
  test -z "$new_short" || sttab_short="$new_short"
}

# Output entry from current sttab_* values
stattab_entry_fields() # ST-Id [Init-Tags]
{
  note "Init fields '$*'"
  test -n "$sttab_id" || stattab_env_init "$1"
  test -z "$1" || shift

  # Output
  stattab_descr
  echo "$sttab_id"
  test -z "$sttab_short" || echo "$sttab_short"
  echo "$sttab_tags" | words_to_lines | remove_dupes
}

# Quietly fetch and parse entry
stattab_entry() # Entry-Id [Tab]
{
  test -n "$sttab_id" || stattab_env_init "$1"
  test -n "$2" || set -- "$1" "$STTAB"
  sttab_re="$(match_grep "$1")"
  stattab_entry="$( $ggrep -m 1 -n "^[0-9 +-]*\b$sttab_re\\ " "$2" )" || return $?
  stattab_entry_parse "$stattab_entry"
}

stattab_entry_env_reset ()
{
  sttab_status=
  sttab_ctime=
  sttab_mtime=
  sttab_vid=
  sttab_short=
  sttab_tags=

  sttab_entry=
  sttab_stat=
  sttab_record=
  sttab_id=
  sttab_primctx=
  sttab_primctx_id=
  sttab_tags_raw=
}

stattab_entry_defaults () # Tags
{
  #test -n "$sttab_tags" || {

  #    sttab_tags "$@"
  #    #stattab_entry_ctx "$@"
  #}

  true
}

# Parse statusdir index file line
stattab_entry_parse () # <Tab-Grep>
{
  test "unset" != "${sttab_base-"unset"}" || local sttab_base=sttab

  # Split grep-line number from rest
  lineno="$(echo "$1" | cut -d ':' -f 1)"
  sttab_entry="$(echo "$1" | cut -d ':' -f 2-)"

  # Split rest into three parts (see stattab format), first stat descriptor part
  sttab_stat="$(echo "$sttab_entry" | grep -o '^[^_A-Za-z]*' )"
  sttab_record="$(echo "$sttab_entry" | sed 's/^[^_A-Za-z]*//' )"
  debug "Parsing descriptor '$sttab_stat' and record '$sttab_record'"

  # Split stat, normally a status bit and two dates
  ${stattab_entry_parse_stat:-"${sttab_base}_parse_STD_stat"} $sttab_stat

  # Now split Id(s) from rest of record with description
  sttab_idspec="$(echo "$sttab_record"|cut -d':' -f1)"
  ${stattab_entry_parse_ids:-"${sttab_base}_parse_STD_ids"} $sttab_idspec

  sttab_rest="$(echo "${sttab_record:$(( ${#sttab_idspec} + 1 ))}")"
  sttab_short="$(echo "${sttab_rest}"|$gsed 's/^\([^[+@<]*\).*$/\1/'|normalize_ws)"
  debug "Id: '$sttab_id'"
  debug "Short: '$sttab_short'"

  sttab_tags_raw="$(echo "$sttab_rest"|$gsed 's/^[^\[+@<]*//'|normalize_ws)"
  sttab_tags="$(echo "$sttab_tags_raw"|$ggrep -o '[+@][^ ]*'|normalize_ws)"
  std_info "Tags: '$sttab_tags'"
  std_info "Tags-Raw: '$sttab_tags_raw'"
}

# Debug env
sttab_env_vars ()
{
  for x in ${!sttab_*}
  do
    echo "$x=${!x}"
  done
}

stattab_exists () # [<Stat-Id>] [<Entry-Type>] [<Stat-Tab>]
{
  grep_f=${grep_f:-"-q"} \
    stattab_grep "${1:-$sttab_id}" "${2:-"id"}" "${3:-$STTAB}"
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
  test $# -ge 1 -a -n "${1-}" -a $# -le 3 || return 64
  { true "${generator:=stattab_tab}"
    $generator "" "${3-}" || ignore_sigpipe
    return $?
  } | {
    test "unset" != "${grep_f-"unset"}" || local grep_f=-m1
    local p_; match_grep_arg "$1"
    case "${2:-"local"}" in
      id )
          $ggrep $grep_f "^[0-9 +-]* $p_:\\?\\(\\ \\|\$\\)" ;;
      alias|ids )
          $ggrep $grep_f "^[0-9 +-]* \\([^:]\+\\ \\)\?$p_\\(\\ [^:]\+\\)\?:\\(\\ \\|\$\\)" ;;
      local )
          $ggrep $grep_f "^[0-9 +-]* [^:]*:$p_:\?\(\\ \|\$\)" ;;
      sub )
          $ggrep $grep_f "^[0-9 +-]* [^ ]*\/$p_:\?\(\\ \|\$\)" ;;
      url )
          $ggrep $grep_f "^[0-9 +-]* [^:]*:\? .* <$p_>\( \|\$\)" ;;
# XXX: is thos correct, it messes up my syntax highlighting
      #literalid )
      #    $ggrep $grep_f "^[0-9 +-]* [^:]*:\?\( .*\)\? ``'$p_\`\`\( \|\$\)" ;;

      ( * ) false ;;
    esac
  }
}

stattab_ids ()
{
  $gsed -E 's/^[0-9 +-]*([^ ]*).*$/\1/'
}

# Generate line and append entry to statusdir index file
stattab_init () # ST-Id [Init-Tags]
{
  note "Initializing $1"
  test -n "$sttab_id" || stattab_env_init "$1"
  stattab_entry_update &&
  stattab_init_show
}

stattab_init_show () #
{
  pref=eval set_always=1 \
    capture_var 'stattab_entry_fields "$@" | normalize_ws' sttab_r new_entry "$@"
  echo "$new_entry" >>"$STTAB"
  return $sttab_r
}

# List ST-Id's only from tab output
stattab_list () # ? LIST
{
  test -n "$2" || set -- "$1" "$STTAB"
  stattab_tab "$@" | stattab_ids
}

# Create new entry with given name
stattab_new () # [NAME]
{
  local NAME="$1"
  test "$NAME" != "''" || NAME=''
  stattab_init "$1"
}

stattab_parse_STD_ids ()
{
  test -z "${1-}" || sttab_id=$1
}

stattab_parse_STD_stat ()
{
  test -z "${1-}" || sttab_status=$1
  test -z "${2-}" || sttab_ctime=$(date_pstat "$2")
  test -z "${3-}" || sttab_mtime=$(date_pstat "$3")
}

stattab_process ()
{
  false
}

# List entries; first argument is glob, converted to (grep) line-regex
stattab_tab () # <Match-Line> [<Stat-Tab>]
{
  test -n "$2" || set -- "$1" "$STTAB"
  test "$1" != "*" || set -- "" "$2"
  test -n "$1" && {
    test -n "${grep_f-}" || local grep_f=-P
    $ggrep $grep_f "$(compile_glob "$1")" "$2" || return
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
}

stattab_value () # ~ <Value>
{
  test -n "${1-}" -a "${1-}" != "-"
}


# Id: BIN:
