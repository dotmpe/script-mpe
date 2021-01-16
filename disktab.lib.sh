#!/bin/sh

# Manage local disks at multiple hosts in plain-text table

disktab_lib_load()
{
  lib_assert statusdir || return
  test -n "${DTAB-}" || DTAB=$(statusdir_run index disk.list 0)
}

disktab_lib_init()
{
  test "${disktab_lib_init-}" = "0" && return
  test -e "$DTAB" || {
    mkdir -p "$(dirname "$DTAB")" && touch "$DTAB"
  }
  dtab_id=
}

disktab_load()
{
  disktab_entry_env && disktab_entry_init "$1" && {
    test -z "$1" || shift
  } && disktab_entry_defaults "$@"
}

disktab_init()
{
  false
}

disktab_entry_init() # Disk-Id
{
  dtab_id="$1"
  echo "$dtab_id" | grep -q '^[A-Za-z_][A-Za-z0-9_-]*$' ||
      error "Illegal Disk-Id '$dtab_id'" 1
}

disktab_entry_update()
{
  test -z "$new_status" || dtab_status="$new_status"
  test -z "$new_ctime" || dtab_ctime="$new_ctime"
  test -z "$new_mtime" || dtab_mtime="$new_mtime"
  test -z "$new_short" || dtab_short="$new_short"
}

# List entries; first argument is glob, converted to (grep) line-regex
disktab_list() # Match-Line
{
  test -n "$2" || set -- "$1" "$DTAB"
  test -n "$1" && {
    grep_f=
    re=$(compile_glob "$1")
    $ggrep $grep_f "$re" "$2" || return
  } || {
    read_nix_style_file "$2" || return
  }
}
# TODO List Disk-Id's
disktab_statlist() # ? LIST
{
  test -n "$2" || set -- "$1" "$DTAB"
  read_nix_style_file "$2"
}

# Generate line and append entry to statusdir index file
disktab_init() # Disk-Id [Init-Tags]
{
  note "Initializing disktab $1"
  test -n "$dtab_id" || disktab_load "$1"
  disktab_entry_update &&
  disktab_init_show >>"$DTAB"
}

disktab_init_show()
{
  pref=eval set_always=1 \
    capture_var 'disktab_entry_fields "$@" | normalize_ws' dtab_r new_entry "$@"
  echo "$new_entry"
  return $dtab_r
}

# Output entry from current dtab_* values
disktab_entry_fields() # Disk-Id [Init-Tags]
{
  note "Init fields '$*'"
  #test -n "$dtab_id" || disktab_load "$1"
  test -n "$dtab_id" || {
      disktab_load "$1"
  }
  test -z "$1" || shift

  # Output
  disktab_descr
  echo "$dtab_id"
  test -z "$dtab_short" || echo "$dtab_short"
  echo "$dtab_tags" | words_to_lines | remove_dupes
}

# Get lines to initial stat descr for
disktab_descr() #
{
  test -n "$dtab_status" || dtab_status=-
  test -n "$dtab_ctime" || dtab_ctime=$( date +"%s" )
  echo "$dtab_status"
  date_id "$dtab_ctime"
}

# Create new entry with given NR
disktab_new() # NR DEV...
{
  local nr dev
  test -n "${1-}" || return
  test -n "${2-}" || set -- "$1" "$(disk_list | head -n 1)"
  nr="$1" dev="$2"
  disk_lsblk_load $dev MODEL TRAN SIZE

  true "${dtab_prefix:="$(mkid "$MODEL-$TRAN-$nr-$SIZE" && echo $id)"}"

  #disktab_init "$1"
  #dtab_model=
  #dtab_serial=
  #dtab_rev=
  #dtab_vendor=
  #dtab_transport=
}

disktab_update()
{
  false
}

# Quietly check wether entry exists, don't capture output
disktab_entry_exists() # Disk-Id [Tab]
{
  false
}

# Quietly fetch and parse entry
disktab_entry() # Disk-Id [Tab]
{
  false
}

# Parse statusdir index file line
disktab_entry_parse() # Tab-Grep
{
  # Split grep-line number from rest
  lineno="$(echo "$1" | cut -d ':' -f 1)"
  dtab_entry="$(echo "$1" | cut -d ':' -f 2-)"

  # Split rest into three parts (see disktab format), first stat descriptor part
  dtab_stat="$(echo "$dtab_entry" | grep -o '^[^_A-Za-z]*' )"
  dtab_record="$(echo "$dtab_entry" | sed 's/^[^_A-Za-z]*//' )"
  debug "Parsing descriptor '$dtab_stat' and record '$dtab_record'"

  disktab_parse_std_descr $dtab_stat

  # Then ID and dtab_short, and rest
  dtab_scrid="$(echo "$dtab_record"|cut -d' ' -f1)"
  dtab_scrid="$(echo "$dtab_record"|cut -d' ' -f1)"
  dtab_short="$(echo "$dtab_record"|cut -d' ' -f2-|$gsed 's/^\([^[+@<]*\).*$/\1/'|normalize_ws)"

  debug "Id: '$dtab_scrid'"
  debug "Short: '$dtab_short'"

  dtab_tags_raw="$(echo "$dtab_record"|cut -d' ' -f2-|$gsed 's/^[^\[+@<]*//'|normalize_ws)"
  dtab_tags="$(echo "$dtab_tags_raw"|$ggrep -o '[+@][^ ]*'|normalize_ws)"

  std_info "Tags: '$dtab_tags'"
  std_info "Tags-Raw: '$dtab_tags_raw'"
}

disktab_parse_std_descr()
{
  test -z "$1" || dtab_status=$1
  test -z "$2" || dtab_ctime=$(date_pstat "$2")
  test -z "$3" || dtab_mtime=$(date_pstat "$3")
}

disktab_entry_fetch() # Disk-Ref
{
  false
}

disktab_entry_env()
{
  dtab_id=
  dtab_vid=
  dtab_entry=
  dtab_primctx=
  dtab_primctx_id=
  dtab_status=
  dtab_stat=
  dtab_ctime=
  dtab_mtime=
  dtab_record=
  dtab_short=
  dtab_tags_raw=
  dtab_tags=
}
