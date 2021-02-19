#!/bin/sh

# Status-Table-Id: stattab
# -Var: sttab/STTAB

stattab_lib_load()
{
  lib_assert statusdir || return
  test -n "${STTAB-}" || STTAB=$(out_fmt= statusdir_lookup stattab.list index)
}

stattab_lib_init()
{
  test "${stattab_lib_init-}" = "0" && return
  test -n "${STTAB-}" || {
    $LOG error "" "Expected STTAB" "$STTAB"
    return 1
  }
  test -e "$STTAB" || {
    test ${init:-0} -eq 0 && {
        $LOG error "" "Expected STTAB" "$STTAB"
        return 1
      }
    mkdir -p "$(dirname "$STTAB")" && touch "$STTAB" || return
  }
  sttab_id=
}

# Prepare env for Stat-Id
stattab_env_prep () # St
{
  stattab_entry_env_reset &&
  stattab_entry_init "$1" && {
    test -z "$1" || shift
  } # XXX: && stattab_entry_defaults "$@"
}

stattab_init()
{
  false
}

stattab_entry_init() # ST
{
  sttab_id="$1"
  echo "$sttab_id" | grep -q '^[A-Za-z_][A-Za-z0-9_-]*$' ||
      error "Illegal ST name '$sttab_id'" 1
}

stattab_entry_update()
{
  test -z "$new_status" || sttab_status="$new_status"
  test -z "$new_ctime" || sttab_ctime="$new_ctime"
  test -z "$new_mtime" || sttab_mtime="$new_mtime"
  test -z "$new_short" || sttab_short="$new_short"
}

# List entries; first argument is glob, converted to (grep) line-regex
stattab_tab () # Match-Line
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

# List ST-Id's only from tab output
stattab_list () # ? LIST
{
  test -n "$2" || set -- "$1" "$STTAB"
  stattab_tab "$@" | $gsed -E 's/^[0-9 +-]*([^ ]*).*$/\1/'
}

# Generate line and append entry to statusdir index file
stattab_init () # ST-Id [Init-Tags]
{
  note "Initializing $1"
  test -n "$sttab_id" || stattab_env_prep "$1"
  stattab_entry_update &&
  stattab_init_show
}

stattab_init_show() #
{
  pref=eval set_always=1 \
    capture_var 'stattab_entry_fields "$@" | normalize_ws' sttab_r new_entry "$@"
  echo "$new_entry" >>"$STTAB"
  return $sttab_r
}

# Output entry from current sttab_* values
stattab_entry_fields() # ST-Id [Init-Tags]
{
  note "Init fields '$*'"
  test -n "$sttab_id" || stattab_env_prep "$1"
  test -z "$1" || shift

  # Output
  stattab_descr
  echo "$sttab_id"
  test -z "$sttab_short" || echo "$sttab_short"
  echo "$sttab_tags" | words_to_lines | remove_dupes
}

# Get lines to initial stat descr for
stattab_descr() #
{
  test -n "$sttab_status" || sttab_status=-
  test -n "$sttab_ctime" || sttab_ctime=$( date +"%s" )
  echo "$sttab_status"
  date_id "$sttab_ctime"
}

# Create new entry with given name
stattab_new() # [NAME]
{
  local NAME="$1"
  test "$NAME" != "''" || NAME=''
  stattab_init "$1"
}

stattab_process()
{
  false
}

stattab_update()
{
  false
}

# Take tab output and perform some sort of grep
stattab_grep () # <Sttab-Id> [<Entry-Type>] [<Stat-Tab>]
{
  test $# -ge 1 -a -n "${1-}" -a $# -le 3 || return 98
  test "unset" != "${generator-"unset"}" || local generator=stattab_tab
  { #test ! -t 0 || {
      $generator "" "${3-}" || ignore_sigpipe
    #}
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
      literalid )
          $ggrep $grep_f "^[0-9 +-]* [^:]*:\?\( .*\)\? ``'$p_\`\`\( \|\$\)" ;;
    esac
  }
}

stattab_exists () # <Stat-Id> [<Stat-Tab>] [<Entry-Type>]
{
  grep_f=${grep_f:-"-q"} stattab_grep "$@"
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
        ${sttab_base}_parse_std_descr $stat || return
        $sttab_act || return
      done
      return $r
  }
}

# Quietly check wether entry exists, don't capture output
stattab_entry_exists () # [<Entry-Id> [<Tab>]]
{
  test -n "${1-}" && { stattab_env_prep "$1" || return 94; }
  test -n "${sttab_id-}" || return 93
# XXX: $ggrep -q '^[0-9 +-]*\b'"$sttab_id"'\b\ ' "$2"
}

# Quietly fetch and parse entry
stattab_entry() # Entry-Id [Tab]
{
  test -n "$sttab_id" || stattab_env_prep "$1"
  test -n "$2" || set -- "$1" "$STTAB"
  sttab_re="$(match_grep "$1")"
  stattab_entry="$( $ggrep -m 1 -n "^[0-9 +-]*\b$sttab_re\\ " "$2" )" || return $?
  stattab_entry_parse "$stattab_entry"
}

# Parse statusdir index file line
stattab_entry_parse() # Tab-Grep
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
  ${stattab_entry_parse_stat:-"${sttab_base}_parse_std_descr"} $sttab_stat

  # Now split Id(s) from rest of record with description
  sttab_idspec="$(echo "$sttab_record"|cut -d':' -f1)"
  ${stattab_entry_parse_ids:-"${sttab_base}_parse_std_ids"} $sttab_idspec

  sttab_rest="$(echo "${sttab_record:$(( ${#sttab_idspec} + 1 ))}")"
  sttab_short="$(echo "${sttab_rest}"|$gsed 's/^\([^[+@<]*\).*$/\1/'|normalize_ws)"
  debug "Id: '$sttab_id'"
  debug "Short: '$sttab_short'"

  sttab_tags_raw="$(echo "$sttab_rest"|$gsed 's/^[^\[+@<]*//'|normalize_ws)"
  sttab_tags="$(echo "$sttab_tags_raw"|$ggrep -o '[+@][^ ]*'|normalize_ws)"
  std_info "Tags: '$sttab_tags'"
  std_info "Tags-Raw: '$sttab_tags_raw'"
}

stattab_parse_std_descr()
{
  test -z "${1-}" || sttab_status=$1
  test -z "${2-}" || sttab_ctime=$(date_pstat "$2")
  test -z "${3-}" || sttab_mtime=$(date_pstat "$3")
}

stattab_parse_std_ids ()
{
  test -z "${1-}" || sttab_id=$1
}

stattab_entry_fetch () # ST-Ref
{
  false
}

stattab_entry_env_reset ()
{
  sttab_id=
  sttab_vid=
  sttab_entry=
  sttab_primctx=
  sttab_primctx_id=
  sttab_status=
  sttab_stat=
  sttab_ctime=
  sttab_mtime=
  sttab_record=
  sttab_short=
  sttab_tags_raw=
  sttab_tags=
}

stattab_entry_defaults() # Tags
{
  #test -n "$sttab_tags" || {

  #    sttab_tags "$@"
  #    #stattab_entry_ctx "$@"
  #}

  true
}

# Debug env
sttab_env_vars ()
{
  for x in ${!sttab_*}
  do
    echo "$x=${!x}"
  done
}

stattab_checkall()
{
  true
}

stattab_updateall()
{
  true
}

stattab_processall()
{
  true
}
