#!/bin/sh


basedir_lib_load()
{
  lib_assert statusdir || return
  test -n "${BDIR_TAB-}" || BDIR_TAB=${STATUSDIR_ROOT}index/basedir.list
}

basedir_lib_init()
{
  test "${basedir_lib_init-}" = "0" && return
  test -e "$BDIR_TAB" || {
    mkdir -p "$(dirname "$BDIR_TAB")" && touch "$BDIR_TAB"
  }
}

basedir_load()
{
  basedir_entry_env && basedir_entry_init "$1" && {
    test -z "$1" || shift
  } && basedir_entry_defaults "$@"
}

basedir_init()
{
  false
}

basedir_entry_init() # BDIR
{
  bdtab_id="$1"
  echo "$bdtab_id" | grep -q '^[A-Za-z_][A-Za-z0-9_-]*$' ||
      error "Illegal BDIR name '$bdtab_id'" 1
}

basedir_entry_update()
{
  test -z "$new_status" || bdtab_status="$new_status"
  test -z "$new_ctime" || bdtab_ctime="$new_ctime"
  test -z "$new_mtime" || bdtab_mtime="$new_mtime"
  test -z "$new_short" || bdtab_short="$new_short"
}

# List entries; first argument is glob, converted to (grep) line-regex
basedir_list() # Match-Line
{
  test -n "$2" || set -- "$1" "$BDIRTAB"
  test -n "$1" && {
    grep_f=
    re=$(compile_glob "$1")
    $ggrep $grep_f "$re" "$2" || return
  } || {
    read_nix_style_file "$2" || return
  }
}

# List SBDIR-Id's
basedir_statlist() # ? LIST
{
  test -n "$2" || set -- "$1" "$BDIRTAB"
  read_nix_style_file "$2" | $gsed -E 's/^[0-9 +-]*([^ ]*).*$/\1/'
}

# Generate line and append entry to statusdir index file
basedir_init() # BDIR-Id [Init-Tags]
{
  note "Initializing $1"
  test -n "$bdtab_id" || basedir_load "$1"
  basedir_entry_update

  pref=eval set_always=1 \
    capture_var 'basedir_entry_fields "$@" | normalize_ws' bdtab_r new_entry "$@"
  echo "$new_entry" >>"$BDIRTAB"
  return $bdtab_r
}

# Output entry from current bdtab_* values
basedir_entry_fields() # BDIR-Id [Init-Tags]
{
  note "Init fields '$*'"
  test -n "$bdtab_id" || basedir_load "$1"
  test -z "$1" || shift

  # Output
  basedir_descr
  echo "$bdtab_id"
  test -z "$bdtab_short" || echo "$bdtab_short"
  echo "$bdtab_tags" | words_to_lines | remove_dupes
}

# Get lines to initial stat descr for
basedir_descr() #
{
  test -n "$bdtab_status" || bdtab_status=-
  test -n "$bdtab_ctime" || bdtab_ctime=$( date +"%s" )
  echo "$bdtab_status"
  date_id "$bdtab_ctime"
}

# Create new entry with given name
basedir_new() # [NAME]
{
  local NAME="$1"
  test "$NAME" != "''" || NAME=''
  basedir_init "$1"
}

basedir_process()
{
  false
}

basedir_update()
{
  false
}

basedir_entry_exists() # Entry-Id [Tab]
{
  test -n "$bdtab_id" || basedir_load "$1"
  test -n "$2" || set -- "$1" "$BDIR_TAB"
  $ggrep -q '^[0-9 +-]*\b'"$bdtab_id"'\b\ ' "$2"
}

basedir_entry() # Entry-Id [Tab]
{
  test -n "$bdtab_id" || basedir_load "$1"
  test -n "$2" || set -- "$1" "$BDIR_TAB"
  bdtab_re="$(match_grep "$1")"
  basedir_entry="$( $ggrep -m 1 -n "^[0-9 +-]*\b$bdtab_re\\ " "$2" )" || return $?
  basedir_entry_parse "$basedir_entry"
}

# Parse basedir index file line
basedir_entry_parse() # Tab-Entry
{
  # Split grep-line number from rest
  lineno="$(echo "$1" | cut -d ':' -f 1)"
  bdtab_entry="$(echo "$1" | cut -d ':' -f 2-)"

  # Split rest into three parts (see basedir format), first stat descriptor part
  bdtab_stat="$(echo "$bdtab_entry" | grep -o '^[^_A-Za-z]*' )"
  bdtab_record="$(echo "$bdtab_entry" | sed 's/^[^_A-Za-z]*//' )"
  debug "Parsing descriptor '$bdtab_stat' and record '$bdtab_record'"

  basedir_parse_std_descr $bdtab_stat

  # Then ID and bdtab_short, and rest
  bdtab_scrid="$(echo "$bdtab_record"|cut -d' ' -f1)"
  bdtab_scrid="$(echo "$bdtab_record"|cut -d' ' -f1)"
  bdtab_short="$(echo "$bdtab_record"|cut -d' ' -f2-|$gsed 's/^\([^[+@<]*\).*$/\1/'|normalize_ws)"

  debug "Id: '$bdtab_scrid'"
  debug "Short: '$bdtab_short'"

  bdtab_tags_raw="$(echo "$bdtab_record"|cut -d' ' -f2-|$gsed 's/^[^\[+@<]*//'|normalize_ws)"
  bdtab_tags="$(echo "$bdtab_tags_raw"|$ggrep -o '[+@][^ ]*'|normalize_ws)"

  std_info "Tags: '$bdtab_tags'"
  std_info "Tags-Raw: '$bdtab_tags_raw'"
}

basedir_parse_std_descr()
{
  test -z "$1" || scr_status=$1
  test -z "$2" || scr_ctime=$(date_pstat "$2")
  test -z "$3" || scr_mtime=$(date_pstat "$3")
}

basedir_entry_fetch() # ST-Ref
{
  false
}

basedir_entry_env()
{
  bdtab_id=
  bdtab_vid=
  bdtab_entry=
  bdtab_primctx=
  bdtab_primctx_id=
  bdtab_status=
  bdtab_stat=
  bdtab_ctime=
  bdtab_mtime=
  bdtab_record=
  bdtab_short=
  bdtab_tags_raw=
  bdtab_tags=
}

basedir_entry_defaults() # Tags
{
  #test -n "$bdtab_tags" || {

  #    bdtab_tags "$@"
  #    #basedir_entry_ctx "$@"
  #}

  true
}

basedir_checkall()
{
  true
}

basedir_updateall()
{
  true
}

basedir_processall()
{
  true
}
