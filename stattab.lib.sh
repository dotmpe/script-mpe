#!/bin/sh

# Status-Table-Id: stattab
# -Var: sttab/STTAB

stattab_lib_load()
{
  lib_assert statusdir
  test -n "$STTAB" || STTAB=${STATUSDIR_ROOT}index/stattab.list
}

stattab_lib_init()
{
  test -e "$STTAB" || {
    mkdir -p "$(dirname "$STTAB")" && touch "$STTAB"
  }
}

stattab_load()
{
  stattab_entry_env && stattab_entry_init "$1" && {
    test -z "$1" || shift
  } && stattab_entry_defaults "$@"
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
stattab_list() # Match-Line
{
  test -n "$2" || set -- "$1" "$STTAB"
  test -n "$1" && {
    grep_f=
    re=$(compile_glob "$1")
    $ggrep $grep_f "$re" "$2" || return
  } || {
    read_nix_style_file "$2" || return
  }
}

# List ST-Id's
stattab_statlist() # ? LIST
{
  test -n "$2" || set -- "$1" "$STTAB"
  read_nix_style_file "$2" | $gsed -E 's/^[0-9 +-]*([^ ]*).*$/\1/'
}

# Generate line and append entry to statusdir index file
stattab_init() # ST-Id [Init-Tags]
{
  note "Initializing $1"
  test -n "$sttab_id" || stattab_load "$1"
  stattab_entry_update

  pref=eval set_always=1 \
    capture_var 'stattab_entry_fields "$@" | normalize_ws' sttab_r new_entry "$@"
  echo "$new_entry" >>"$STTAB"
  return $sttab_r
}

# Output entry from current sttab_* values
stattab_entry_fields() # ST-Id [Init-Tags]
{
  note "Init fields '$*'"
  test -n "$sttab_id" || stattab_load "$1"
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

stattab_entry_exists() # Entry-Id [Tab]
{
  test -n "$sttab_id" || stattab_load "$1"
  test -n "$2" || set -- "$1" "$STTAB"
  $ggrep -q '^[0-9 +-]*\b'"$sttab_id"'\b\ ' "$2"
}

stattab_entry() # Entry-Id [Tab]
{
  test -n "$sttab_id" || stattab_load "$1"
  test -n "$2" || set -- "$1" "$STTAB"
  sttab_re="$(match_grep "$1")"
  stattab_entry="$( $ggrep -m 1 -n "^[0-9 +-]*\b$sttab_re\\ " "$2" )" || return $?
  stattab_entry_parse "$stattab_entry"
}

# Parse statusdir index file line
stattab_entry_parse() # Tab-Entry
{
  # Split grep-line number from rest
  lineno="$(echo "$1" | cut -d ':' -f 1)"
  sttab_entry="$(echo "$1" | cut -d ':' -f 2-)"

  # Split rest into three parts (see stattab format), first stat descriptor part
  sttab_stat="$(echo "$sttab_entry" | grep -o '^[^_A-Za-z]*' )"
  sttab_record="$(echo "$sttab_entry" | sed 's/^[^_A-Za-z]*//' )"
  debug "Parsing descriptor '$sttab_stat' and record '$sttab_record'"

  stattab_parse_std_descr $sttab_stat

  # Then ID and sttab_short, and rest
  sttab_scrid="$(echo "$sttab_record"|cut -d' ' -f1)"
  sttab_scrid="$(echo "$sttab_record"|cut -d' ' -f1)"
  sttab_short="$(echo "$sttab_record"|cut -d' ' -f2-|$gsed 's/^\([^[+@<]*\).*$/\1/'|normalize_ws)"

  debug "Id: '$sttab_scrid'"
  debug "Short: '$sttab_short'"

  sttab_tags_raw="$(echo "$sttab_record"|cut -d' ' -f2-|$gsed 's/^[^\[+@<]*//'|normalize_ws)"
  sttab_tags="$(echo "$sttab_tags_raw"|$ggrep -o '[+@][^ ]*'|normalize_ws)"

  std_info "Tags: '$sttab_tags'"
  std_info "Tags-Raw: '$sttab_tags_raw'"
}

stattab_parse_std_descr()
{
  test -z "$1" || scr_status=$1
  test -z "$2" || scr_ctime=$(date_pstat "$2")
  test -z "$3" || scr_mtime=$(date_pstat "$3")
}

stattab_entry_fetch() # ST-Ref
{
  false
}

stattab_entry_env()
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
