scrtab_lib__load ()
{
  lib_assert statusdir || return
  test -n "${SCRDIR-}" || SCRDIR=$HOME/.local/scr.d
  test -n "${SCRTAB-}" || SCRTAB=${STATUSDIR_ROOT}index/scrtab.list
}

scrtab_lib__init ()
{
  test -z "${scrtab_lib_init:-}" || return $_
  test -d "$SCRDIR" || {
    mkdir -p "$SCRDIR" || return
  }
  test -e "$SCRTAB" || {
    mkdir -p "$(dirname "$SCRTAB")" && touch "$SCRTAB"
  }
  test -n "${package_lists_contexts_default-}" || package_lists_contexts_default=@Std
}

# Prepare env for Scr-Id
scrtab_env_prep () # Scr
{
  scrtab_entry_env_reset && scrtab_entry_init "$@" && {
      test -z "$1" || shift
  } && scrtab_entry_defaults "$@"
}

# Set src-src and src-id and check input
scrtab_entry_init () # Scr-Id Scr-Src Scr-Tags
{
  true "${scr_ext:="sh"}"
  test -e "${1-}" && set -- "$(basename "$1" .$scr_ext)" "$@"
  test -e "${2-}" && {
    scr_src="$2"
    test ${choice_alias:-0} -ne 1 && {
      scr_scr="$(cat "$scr_src")"
    } || {
      scr_scr="$scr_src"
    }
  } || {
    test ${choice_alias:-0} -ne 1 || return 97
    scr_scr="${2-}"
  }
  scr_id="$1"
  shift 2
  echo "$scr_id" | grep -q '^[A-Za-z_][A-Za-z0-9_-]*$' ||
      error "Illegal SCR name Id '$scr_id'" 1
}

scrtab_entry_name() # Tags...
{
  test -n "$scr_primctx" || scrtab_entry_ctx "$@"
  set -- $scr_tags ; shift ; test $# -gt 0 && set -- "-" "$@" || set --
  local sid
  upper=0 mksid "$scr_primctx_id-$username-$hostname$*"
  scr_id="$sid"
  scr_src=
  note "New Id $scr_id"
}

# Output script wrapped in function
scrtab_entry_create () # [Scr-Src]
{
cat <<EOM
#!/bin/bash

$(
test -z "${scr_author-}" || echo ${scr_vid}__author=\'$scr_author\'
test -z "${scr_short-}" || echo ${scr_vid}__about=\'$scr_short\'
test -z "${scr_man-}" || echo ${scr_vid}__description=\'$scr_man\'
test -z "${scr_param-}" || echo ${scr_vid}__param=\'$scr_param\'
test -z "${scr_example-}" || echo ${scr_vid}__example=\'$scr_example\'
test -z "${scr_group-}" || echo ${scr_vid}__group=\'$scr_group\' )
$scr_vid ()
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
  test -n "${2-}" || set -- "${1-}" "$SCRTAB"
  test -n "${1-}" && {
    grep_f=
    re=$(compile_glob "$1")
    $ggrep $grep_f "$re" "$2" || return
  } || {
    read_nix_style_file "$2" || return
  }
}

# List SCR-Id's
scrtab_scrlist () # ? LIST
{
  test -n "${2-}" || set -- "${1-}" "$SCRTAB"
  read_nix_style_file "$2" | $gsed -E 's/^[0-9 +-]*([^ ]*).*$/\1/'
}

# Generate line and append entry to statusdir index file
scrtab_init () # SCR-Id [Init-Tags]
{
  test -n "$scr_id" && {
    note "Initializing '$scr_id'"
  } || {
    note "Initializing '$1'"
    scrtab_env_prep "$1" || return; }

  scrtab_entry_update
  true "${scr_status:=}"
  true "${scr_ctime:=}"
  true "${scr_mtime:=}"
  true "${scr_short:=}"

  scrtab_entry_fields "$@" | normalize_ws; echo
}

# Output entry from current scr_* values
scrtab_entry_fields () # SCR-Id [Init-Tags]
{
  note "Init fields '$*'"
  #test -n "$scr_src" || { scrtab_env_prep "$1" || return; }
  test $# -eq 0 || shift
  # Process scr_tags_raw, etc. and capture ret, set scr_tags
  #set_always=1 pref= capture_var scr_tags scr_tags_status "" "$@"
  #test $scr_tags_status -eq 0 || {
  #  error "SCR-tags failed '$*'" 1
  #}

  # Output
  scrtab_descr
  echo "$scr_id"
  test -z "$scr_short" || echo "$scr_short"
  test -n "${scr_file-}" &&
      printf '<%s>\n' "$scr_file" || {
          test -z "${scr_scr-}" ||
              printf '``%s``\n' "$scr_scr"
      }
  echo "$scr_tags" | words_to_lines | remove_dupes
}

# Get lines to initial stat descr for
scrtab_descr () #
{
  test -n "$scr_status" || scr_status=- # Status indicates record processed successfully
  test -n "$scr_ctime" || scr_ctime=$( date +"%s" ) # Record was last changed
  test -n "$scr_mtime" || scr_mtime=- # Script was last modified
  echo "$scr_status"
  test "${scr_ctime:--}" = "-" && echo "$scr_ctime" || date_id "@$scr_ctime"
  test "${scr_mtime:--}" = "-" && echo "$scr_mtime" || date_id "@$scr_mtime"
}

scrtab_entry_ctx ()
{
  test $# -gt 0 || set -- $package_lists_contexts_default
  test $# -gt 0 || set -- @Std
  scr_tags="$*"
  scr_tags_raw="$scr_tags"
  scr_primctx="$1"

  # Make ID of first tag (without metachars)
  #upper=0 mkvid "$(str_slice "$scr_primctx" 2)" || return
  local vid ; upper=0 mkvid "${scr_primctx:1}"
  scr_primctx_id="$vid"

  # export scr_tags

  note "scrtab: Prim-Ctx: $scr_primctx_id Tags: $scr_tags"
}

# Get tags for scr, src-file, use primary class from package/env to continue
scr_tags() #
{
  test -n "${scr_primctx_id-}" || return 0
  lib_load ctx-${scr_primctx_id} && scr__${scr_primctx_id}__tags "$@"
}

# Create new entry with given name and command. Name can be left out: a default
# is generated. To create a script file instead of storing command inline, set
# the --script option. Prefix scriptfile with '@' to use contents as command.
#
scrtab_new () # [--script] [--alias] [--proc] [NAME] CMD [TAGS...]
{
  test $# -ge 1 || return 98
  scrtab_entry_init "$@"; shift $(test -e "$1" && echo 1 || echo 2)
  scrtab_entry_ctx "$@" || return

  test -n "${scr_id-}" || {
    test -e "$scr_src" && {
      scr_id="$(basename $1 .$scr_ext)"
    } || {
      scrtab_entry_name $scr_tags || return
    }
    scrtab_entry_exists "$scr_id" && {
      scrtab_id_nr || return
    } || true
  }
  scrtab_entry_defaults $scr_tags || return

  test -z "$scr_file" || {
      test -e "$scr_src" && {
        scrtab_entry_create "$scr_src" > $scr_file || return
      } || {
        echo "$scr_scr" | scrtab_entry_create > $scr_file || return
      }
  }

  test ${choice_proc:-0} -ne 1 || scrtab_proc

  scrtab_init >>$SCRTAB
}

# Apply status and record values where changed, but don't update entry yet
scrtab_proc ()
{
  test -n "$scr_src" || { scrtab_env_prep "$1" || return; }
  test -e "${scr_file-}" || error "scrtab-proc: SCR file required: ${1-}" 1

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

scrtab_entry_update ()
{
  test -z "${new_status-}" || scr_status="$new_status"
  test -z "${new_ctime-}" || scr_ctime="$new_ctime"
  test -z "${new_mtime-}" || scr_mtime="$new_mtime"
  test -z "${new_short-}" || scr_short="$new_short"
}

# Replace scrid line with freshly generated data. This will re-use existing
# scrtab-entry env
scrtab_update() # SCR-Id [Tags]
{
  test -n "$scr_src" || { scrtab_env_prep "$1" || return; }
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

scrtab_entry_exists () # [SCR-Id] [LIST]
{
  test -n "${2-}" || set -- "${1-}" "$SCRTAB"
  $ggrep -q "^[0-9 +-]*\b${1:-$scr_id}\\ " "$2"
}

scrtab_id_nr () # SCR-Name [LIST]
{
  test -n "${2-}" || set -- "${1-}" "$SCRTAB"
  last_id=$( $ggrep -o "^[0-9 +-]*\b${1:-$scr_id}-[0-9]*\\ " "$2"|sed 's/^.*-\([0-9]*\) *$/\1/'|sort -n|tail -n 1)
  debug "Last Id: $last_id"
  scr_id=$scr_id-$(( $last_id + 1 ))
  stderr info "New Id: $scr_id"
}

# Parse statusdir index file line
scrtab_entry() # ~ SCR-Id
{
  test -n "${scr_src:-}" || { scrtab_env_prep "$1" || return; }
  test -n "${2-}" || set -- "${1-}" "$SCRTAB"
  scr_re="$(match_grep "$1")"
  scrtab_entry="$(
    scrtab_list | $ggrep -m 1 -n "^[0-9 +-]*\b$scr_re\\ " "$2" )" || return $?
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

  # scr_file="$(htd prefixes expand "$scr_ref")"
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
  scrtab_parse "$(scrtab_entry "$1" )" || error "No entry '$1'" 1
  test -n "$scr_status" || error "Error parsing" 1
}

scrtab_entry_env_reset ()
{
  # Stat and record bits
  scr_status=
  scr_ctime=
  scr_mtime=
  scr_id=
  scr_short=

  scr_primctx=
  scr_primctx_id=
  scr_tags_raw=
  scr_tags=

  # Parts left by parser
  scr_entry=
  scr_record=
  scr_stat=

  # Basename for source-file, with unique Id and script
  scr_basename=
  # Full (absolute) path for source-file
  src_file=
  # Function for source-file
  scr_vid=
  # Full source for script
  scr_scr=
  # Source path for script (only during create)
  scr_src=
}

scrtab_entry_defaults () # Tags
{
  test ${choice_script:-0} -eq 1 && {
      true "${scr_ext:="sh"}"
      true "${scr_basename:="$scr_id.$scr_ext"}"
      scr_file="$SCRDIR/$scr_basename"
  } || scr_file=

  true "${scr_vid:="$( upper=0 mkvid "$scr_id" && echo "$vid" )"}"

  test -n "$scr_tags" || {

      scr_tags "$@"
      #scrtab_entry_ctx "$@"
  }
}

# Debug env
scrtab_env_vars ()
{
  for x in SCRDIR SCRTAB ${!scr_*} ${!scrtab_*}
  do
    echo "$x=${!x}"
  done
}

scrtab_check() # SCR-Id [Tags]
{
  test -n "$scr_src" || scrtab_env_prep "$1"
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
    test -z "${scr_file-}" ||
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
  scrtab_env_prep "$1"
  shift
  scrtab_entry_fetch "$scr_id"
  htd__show "$@"
}
