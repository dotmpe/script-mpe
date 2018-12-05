#!/bin/sh

scrtab_lib_load()
{
  test -n "$STATUSDIR_ROOT" || STATUSDIR_ROOT=$HOME/.statusdir
  test -n "$SCRDIR" || SCRDIR=$HOME/.local/scr.d
  test -d "$SCRDIR" || {
    mkdir -p "$SCRDIR" || return
  }
  test -n "$SCRTAB" || SCRTAB=${STATUSDIR_ROOT}/index/scrtab.list
  test -e "$SCRTAB" || {
    touch "$SCRTAB" || return
  }
}

scrtab_load()
{
  scrtab_entry_env && scrtab_entry_init "$1" && {
    test -z "$1" || shift
  } && scrtab_entry_defaults "$@"
}

scrtab_entry_init() # SCR
{
  scr_src="$1"
  scr_id="$(basename "$1" .sh)"
  echo "$scr_id" | grep -q '^[A-Za-z_][A-Za-z0-9_-]*$' ||
      error "Illegal SCR name '$scr_id'" 1
}

scrtab_entry_name() # Tags...
{
  test -n "$scrtab_primctx" || scrtab_entry_ctx "$@"
  set -- $scr_tags ; shift ; test -n "$1" && set -- "-" "$@" || set -- ""
  upper=0 mksid "$scrtab_primctx_id-$username-$hostname$*"
  scr_id="$sid"
  scr_src=
  scrtab_entry_defaults $scr_tags
  note "New name $scr_src"
}

scrtab_entry_create() # Src-Id [-|Scr-Src-File]
{
  test -n "$scr_src" || scrtab_load "$1"
  test -n "$2" -o -z "$src_file" || set -- "$1" "$src_file"
cat <<EOM
#!/bin/bash

$(
test -z "$scr_author" || echo ${scr_vid}__author='$scr_author'
test -z "$scr_short" || echo ${scr_vid}__about='$scr_short'
test -z "$scr_man" || echo ${scr_vid}__description='$scr_man'
test -z "$scr_param" || echo ${scr_vid}__param='$scr_param'
test -z "$scr_example" || echo ${scr_vid}__example='$scr_example'
test -z "$scr_group" || echo ${scr_vid}__group='$scr_group' )
$scr_vid()
{
EOM
  shift
  # Add script, bash-bang (lines) stripped and indented
  grep -v '^\#\!\/' "$@" | sed 's/^\(..*\)$/  \1/'
  echo "}"
}

# List entries; first argument is glob, converted to (grep) line-regex
scrtab_list() # Match-Line
{
  test -n "$2" || set -- "$1" "$SCRTAB"
  test -n "$1" && {
    grep_f=
    re=$(compile_glob "$1")
    $ggrep $grep_f "$re" "$2" || return
  } || {
    read_nix_style_file "$2" || return
  }
}

# List SCR-Id's
scrtab_scrlist() # ? LIST
{
  test -n "$2" || set -- "$1" "$SCRTAB"
  read_nix_style_file "$2" | $gsed -E 's/^[0-9 +-]*([^ ]*).*$/\1/'
}

# Generate line and append entry to statusdir index file
scrtab_init() # SCR-Id [Init-Tags]
{
  note "Initializing $1"
  test -n "$scr_src" || scrtab_load "$1"
  scrtab_entry_update

  pref=eval set_always=1 \
    capture_var 'scrtab_entry_fields "$@" | normalize_ws' scr_r new_entry "$@"
  echo "$new_entry" >> "$SCRTAB"
  return $scr_r
}

# Output entry from current scr_* values
scrtab_entry_fields() # SCR-Id [Init-Tags]
{
  note "Init fields '$*'"

  test -n "$scr_src" || scrtab_load "$1"
  test -z "$1" || shift

  # Process scr_tags_raw, etc. and capture ret, set scr_tags
  set_always=1 pref= capture_var scr_tags scr_tags_status "" "$@"
  test $scr_tags_status -eq 0 || {
    error "SCR-tags failed '$*'" 1
  }

  # Output
  scrtab_descr
  echo "$scr_id"
  test -z "$scr_short" || echo "$scr_short"
  echo "$scr_tags" | words_to_lines | remove_dupes
}

# Get lines to initial stat descr for
scrtab_descr() #
{
  test -n "$scr_status" || scr_status=- # Status indicates record processed successfully
  test -n "$scr_ctime" || scr_ctime=$( date +"%s" ) # Record was last changed
  test -n "$scr_mtime" || scr_mtime=- # Script was last modified
  echo "$scr_status"
  date_id "$scr_ctime"
  date_id "$scr_mtime"
}

scrtab_entry_ctx()
{
  test -n "$scr_tags" || scr_tags="$* $package_lists_contexts_default"
  test -n "$scr_tags" || scr_tags="$package_lists_contexts_default"
  test -n "$scr_tags" || scr_tags=@Std
  test -n "$scr_tags_raw" || scr_tags_raw="$scr_tags"

  test -n "$1" || set -- @Std

  export scrtab_primctx="$1"

  # Make ID of first tag (without metachars)
  upper=0 mkvid "$(str_slice "$scrtab_primctx" 2)"

  export scrtab_primctx_id="$vid"
  export scr_tags="$*"

  note "scrtab: Prim-Ctx: $scrtab_primctx_id Tags: $scr_tags"
}

# Get tags for scr, src-file, use primary class from package/env to continue
scr_tags() #
{
  test -n "$scrtab_primctx_id" || return 0
  lib_load ctx-${scrtab_primctx_id} && scr__${scrtab_primctx_id}__tags "$@"
}

# Create new entry with given name and command. Name can be left out, a default
# is generated. To create a script file instead of storing command inline, set
# the script option. Provide an existing (path to) filename, and its contents
# is used as command. Alternatively, set alias to make an alias to a local
# script and generate an function envelope upon processing by scrtab.
#
scrtab_new() # [--script | --alias] [NAME] [CMD] [TAGS...]
{
  local NAME="$1" CMD="$2" ;
  test "$NAME" != "''" || NAME=''
  test "$CMD" != "''" || CMD=''

  test $# -gt 2 && shift 2 || set -- $package_lists_contexts_default
  scrtab_entry_ctx "$@"

  test -z "$CMD" -o -n "$NAME" && {
    test -z "$NAME" || {

        scrtab_entry_init $NAME
        scrtab_initid
        scrtab_entry_defaults $scr_tags
    }

  } || {
    # Set default name for CMD
    scrtab_entry_name $scr_tags
    scrtab_entry_init $scr_src
    scrtab_initid
    scrtab_entry_defaults $scr_tags
    NAME="$scr_src"
  }

  #test -n "$scr_src" || scrtab_load "$NAME"
  #stderr info "ScrTab: $scr_id $scr_src $scr_vid"
  #stderr info "Tags: '$scr_primctx' '$scr_tags' '$scr_tags_raw'"

  scrtab_entry_exists "$scr_id" && error "Entry '$scr_id' exists" 1

  test -e "$scr_src" && {
    stderr note "'$scr_src' '$SCRDIR/$scr_id.sh'"
    scrtab_entry_create "" "$scr_src" > $SCRDIR/$scr_id.sh
  } || {
    test -z "$CMD" || {
      echo "$CMD" | scrtab_entry_create > $SCRDIR/$scr_id.sh
    }
  }

  test -n "$scr_status" -a "$scr_status" != "-" || scrtab_proc
  scrtab_init
}

# Apply status and record values where changed, but don't update entry yet
scrtab_proc()
{
  test -n "$scr_src" || scrtab_load "$1"
  test -e "$scr_file" || error "scrtab-proc: SCR file required: $1" 1

  # Parse
  stderr note "Process"
  ( . $scr_file ) && new_status=0 || new_status=$?
  stderr note "Process $new_status"

  # Notice mtime changes
  test -e "$scr_src" &&
      cur_mtime=$(filemtime "$scr_src") ||
      cur_mtime=$(filemtime "$scr_file")
  test -n "$scr_mtime" -a "$scr_mtime" != "-" && {

    test $cur_mtime -le $scr_mtime && {
        test $cur_mtime -eq $scr_mtime || {
            touch_ts "@$scr_mtime" "$scr_file"
        }
    } || {
        new_mtime=$cur_mtime
    }
  } || scr_mtime=$cur_mtime
}

scrtab_entry_update()
{
  test -z "$new_status" || scr_status="$new_status"
  test -z "$new_ctime" || scr_ctime="$new_ctime"
  test -z "$new_mtime" || scr_mtime="$new_mtime"
  test -z "$new_short" || scr_short="$new_short"
}

# Replace scrid line with freshly generated data. This will re-use existing
# scrtab-entry env
scrtab_update() # SCR-Id [Tags]
{
  test -n "$scr_src" || scrtab_load "$1"
  test -n "$scr_src" || error "scrtab-update: SCR required: $1" 1
  test -n "$scr_entry" || scrtab_entry_fetch "$1"
  debug "Entry '$scr_entry'"

  test -z "$cached" -o -n "$scrtab_update_cached" || scrtab_update_cached=$cached
  test -z "$reset" -o -n "$scrtab_process" || scrtab_process=$reset

  new_mtime="$(filemtime "$scr_file")"
  test $scr_mtime -eq $new_mtime || {
    scrtab_update_cached=1
    scrtab_process=1
  }

  # If unless process is requested, only update if status is not OK
  {
      trueish "$scrtab_update_cached" ||
      test "$scr_status" != "0" -o "$scr_status" != "200"
  } || { stderr note "No process and status:$scr_status OK " ; return 0 ; }

  {
      trueish "$scrtab_process" || test "$scr_status" = "-"
  } || { stderr note "No reset and status:$scr_status cached" ; return 0 ; }


  not_trueish "$scrtab_update_cached" && {

      scrtab_entry_update

      pref=eval set_always=1 \
          capture_var 'scrtab_entry_fields "$@" | normalize_ws' scr_r new_entry "$@"

      debug "new '$new_entry'"
      test "$new_entry" != "$scr_entry" || {
        stderr info "No stat or record changes"
        return
      }

    } || {

      scrtab_proc "$scr_src"
      scrtab_init

      pref=eval set_always=1 \
          capture_var 'scrtab_entry_fields "$@" | normalize_ws' scr_r new_entry "$@"
    }

  file_replace_at "$SCRTAB" "$lineno" "$new_entry"
  note "Updated $scr_src entry (at line $lineno)"
}

scrtab_entry_exists() # SCR-Id [LIST]
{
  test -n "$scr_src" || scrtab_load "$1"
  test -n "$2" || set -- "$1" "$SCRTAB"
  $ggrep -q "^[0-9 +-]*\b$scr_id\\ " "$2"
}

scrtab_initid() # SCR-Name [LIST]
{
  test -n "$scr_id" || scrtab_load "$1"
  test -n "$2" || set -- "$1" "$SCRTAB"
  last_id=$( $ggrep -o "^[0-9 +-]*\b$scr_id-[0-9]*\\ " "$2"|sed 's/^.*-\([0-9]*\) *$/\1/'|sort -n|tail -n 1)
  debug "Last Id: $last_id"
  scr_id=$scr_id-$(( $last_id + 1 ))
  stderr info "New Id: $scr_id"
}

# Parse statusdir index file line for {PREFNAME}$id (from env, see scrtab-file-env)
# Provide ctx arg to parse descriptor iso. primary context (if func exists)
scrtab_entry() # SCR-Id
{
  test -n "$scr_src" || scrtab_load "$1"
  test -n "$2" || set -- "$1" "$SCRTAB"
  scr_re="$(match_grep "$1")"
  scrtab_entry="$( $ggrep -m 1 -n "^[0-9 +-]*\b$scr_re\\ " "$2" )" || return $?
  scrtab_parse "$scrtab_entry"
}

# Parse statusdir index file line
scrtab_parse() # Tab-Entry
{
  # Split grep-line number from rest
  lineno="$(echo "$1" | cut -d ':' -f 1)"
  scr_entry="$(echo "$1" | cut -d ':' -f 2-)"

  # Split rest into three parts (see scrtab format), first stat descriptor part
  scr_stat="$(echo "$scr_entry" | grep -o '^[^_A-Za-z]*' )"
  scr_record="$(echo "$scr_entry" | sed 's/^[^_A-Za-z]*//' )"
  debug "Parsing descriptor '$scr_stat' and record '$scr_record'"

  scrtab_parse_std_descr $scr_stat

  # Then ID and scr_short, and rest
  scr_scrid="$(echo "$scr_record"|cut -d' ' -f1)"
  scr_scrid="$(echo "$scr_record"|cut -d' ' -f1)"
  scr_short="$(echo "$scr_record"|cut -d' ' -f2-|$gsed 's/^\([^[+@<]*\).*$/\1/'|normalize_ws)"

  debug "Id: '$scr_scrid'"
  debug "Short: '$scr_short'"

  scr_tags_raw="$(echo "$scr_record"|cut -d' ' -f2-|$gsed 's/^[^\[+@<]*//'|normalize_ws)"
  scr_tags="$(echo "$scr_tags_raw"|$ggrep -o '[+@][^ ]*'|normalize_ws)"

  stderr info "Tags: '$scr_tags'"
  stderr info "Tags-Raw: '$scr_tags_raw'"

  scr_ref="$(echo "$scr_tags_raw"|sed 's/^[^<]*<\([^>]*\)>.*/\1/')"
  scr_file="$(htd prefixes expand "$scr_ref")"
  note "Src: <$scr_ref>"
}

scrtab_parse_std_descr()
{
  test -z "$1" || scr_status=$1
  test -z "$2" || scr_ctime=$(date_pstat "$2")
  test -z "$3" || scr_mtime=$(date_pstat "$3")
}

scrtab_entry_fetch() # SCR-Id
{
  scrtab_entry "$1" || error "No entry '$1'" 1
  test -n "$scr_status" || error "Error parsing" 1
}

scrtab_entry_env()
{
  scr_id=
  scr_src=
  scr_vid=
  scr_entry=
  scr_primctx=
  scr_primctx_id=
  scr_status=
  scr_stat=
  scr_ctime=
  scr_mtime=
  scr_record=
  scr_id=
  scr_short=
  scr_tags_raw=
  scr_tags=
}

scrtab_entry_defaults() # Tags
{
  test -n "$scr_src" || {
      scr_src="$scr_id.sh"
      scr_file="$SCRDIR/$scr_id.sh"
      upper=0 mkvid "$scr_id" ; scr_vid="$vid"
  }

  test -n "$scr_tags" || {

      scr_tags "$@"
      #scrtab_entry_ctx "$@"
  }
}

scrtab_check() # SCR-Id [Tags]
{
  test -n "$scr_src" || scrtab_load "$1"
  test -n "$1" || set -- "$scr_src"
  scrtab_entry_exists "$1" && {

    scrtab_update "$@" || error "In scrtab-update: $?: '$*'" $?

  } || {

    scrtab_init "$@" || error "In scrtab-init: $?: '$*'" $?
  }
}

scrtab_checkall()
{
  test -n "$Init_Tags" || Init_Tags="$package_lists_contexts_default"
  test -z "$update" -o -n "$scrtab_process_reset" || scrtab_process_reset=$update
  update=
  test -z "$process" -o -n "$scrtab_update_cached" || scrtab_update_cached=$process
  process=

  scrtab_checkall_inner()
  {
    test -z "$scr_file" ||
      note "SCRStat checking '$scr_file': '$1' '$Init_Tags'"
    scr_src= scrtab_check "$1" $Init_Tags || {
      echo "scrtab:checkall:inner:$1:$Init_Tags" | tr -c 'a-z0-9:' ':' >>"$failed"
    }
  }
  p= s= act=scrtab_checkall_inner foreach_do "$@"
}

scrtab_updateall()
{
  scrtab_update_cached=$process scrtab_process_reset=1 scrtab_checkall "$@"
}

scrtab_processall()
{
  scrtab_update_cached=1 scrtab_process_reset=1 scrtab_checkall "$@"
}

htd_scrtab_show() # Var-Names...
{
  htd__show "$@"
}

htd_scrtab_entry_show() # Scr-Id Var-Names...
{
  scrtab_load "$1"
  shift
  scrtab_entry_fetch "$scr_id"
  htd__show "$@"
}
