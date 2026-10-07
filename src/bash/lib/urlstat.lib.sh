#!/bin/sh


urlstat_lib__load ()
{
  lib_require statusdir || return
  test -n "${URLSTAT_TAB-}" || URLSTAT_TAB=${STATUSDIR_ROOT}index/urlstat.list
  test -n "${urlstat_invalid-}" || urlstat_invalid="!@Invalid !@Template"
}

urlstat_lib__init ()
{
  test "${urlstat_lib_init-}" = "0" && return
  test -e "$URLSTAT_TAB" || {
    touch "$URLSTAT_TAB" || return
  }
  ! sys_debug -dev -debug -init ||
    $LOG notice "" "Initialized urlstat.lib" "$(sys_debug_tag)"
}

# Get lines to initial stat descr for
urlstat_descr() #
{
  test -n "$status" || status=- # Status indicates record processed successfully
  test -n "$ctime" || ctime=$( date +"%s" ) # Record was last changed
  test -n "$btime" || btime=$( min $ctime $mtime $(date +"%s" )) # Original date, birth date, or First seen
  test -n "$ltime" || ltime=- # Resource was last retrieved
  test -n "$mtime" || mtime=- # Resource was last changed
  echo "$status"
  date_id "$ctime"
  date_id "$btime"
  date_id "$ltime"
  date_id "$mtime"
}

# Get tags for url, src-file
urlstat_tags() #
{
  std_info "Tags for '$urlstat_src' '$urlstat_file'"
  test -z "$*" || {
    words_to_lines "$@"
  }
  # Get tags for source-file
  test -z "$urlstat_file" || {
    fnmatch "to/*" "$urlstat_file" && {
      lib_load tasks
      tasks_hub_tags "$urlstat_file"
    }
    package_lists_contexts_map "$urlstat_file"
    echo "<$( htd prefix name "$urlstat_file" )>"
  }
}

urlstat_process()
{
  test -n "$urlstat_src" || urlstat_entry_init "$1"
  test -n "$1" -a -n "$urlstat_src" || error "urlstat-process: URL required: $1" 1
  test -n "$urlstat_entry" || urlstat_entry_fetch "$1"
  debug "entry '$entry'"

  case "$urlstat_src" in

      http|https )

          status=$(curl -sSo/dev/null -m10 "$urlstat_src" --write-out %{http_code})
          fnmatch "1*" "$status" && status=1
          test "$status" = "200" && status=0 || {
            fnmatch "2*" "$status" && status=2
          }
          fnmatch "3*" "$status" && status=3
          fnmatch "4*" "$status" && status=4
          fnmatch "5*" "$status" && status=5
          #test -n "$title"
        ;;

      * ) ;; # XXX: urlstat unknown protocol
  esac
}

# Replace uriref line with freshly generated data. This will re-use existing
# urlstat-entry env
urlstat_update() # URI-Ref [Tags]
{
  test -n "$urlstat_src" || urlstat_entry_init "$1"
  test -n "$1" -a -n "$urlstat_src" || error "urlstat-update: URL required: $1" 1
  test -n "$urlstat_entry" || urlstat_entry_fetch "$1"
  debug "entry '$entry'"
  test -z "$process" -o -n "$urlstat_update_process" ||
      urlstat_update_process=$process
  test -z "$refresh" -o -n "$urlstat_process_refresh" ||
      urlstat_process_refresh=$refresh

  # If unless process is requested, only update if status is not OK
  {
      trueish "$urlstat_update_process" ||
      test "$status" != "0" -o "$status" != "200"
  } || { note "No process and status:$status OK " ; return 0 ; }

  {
      trueish "$urlstat_process_refresh" || test "$status" = "-"
  } || { note "No refresh and status:$status cached" ; return 0 ; }

  test -z "$new_status" || status="$new_status"
  test -z "$new_ctime" || ctime="$new_ctime"
  test -z "$new_btime" || btime="$new_btime"
  test -z "$new_ltime" || ltime="$new_ltime"
  test -z "$new_mtime" || mtime="$new_mtime"
  test -z "$new_title" || title="$new_title"

  not_trueish "$urlstat_update_process" && {
      new_entry="$(urlstat_init_fields "$@" | normalize_ws )"
      debug "new '$new_entry'"
      test "$new_entry" != "$entry" || {
        std_info "No stat or record changes"
        return
      }

    } || {

      urlstat_process "$urlstat_src"
      new_entry="$(urlstat_init_fields "$@" | normalize_ws )"
    }
  file_replace_at "$URLSTAT_TAB" "$lineno" "$new_entry"
  note "Updated $urlstat_src entry (at line $lineno)"
}
urlstat_check () # <URI-Ref> [<Tags>]
{
  test $# -gt 0 || set -- "" $urlstat_invalid
  $LOG error "" "TODO" "" 1
  return
  urlstat_fetch "$@"

  test -n "${1-}" && {
    urlstat_entry_init "$1" || return 97
  } || set -- "$urlstat_src"
  test -n "$1" || return 98

  urlstat_entry_exists "$1" && {

    urlstat_entry_fetch "$1" || return $?
    note "Found $uriref"

    test -z "$update" -o -n "$urlstat_check_update" || urlstat_check_update=$update
    test -z "$process" -o -n "$urlstat_update_process" || urlstat_update_process=$process

    # Don't update if ID is present and default stats have not been updated
    {
      trueish "$urlstat_check_update" ||
      trueish "$urlstat_update_process" ||
      test "$stat" != "$(urlstat_descr)"
    } || { std_info "No update or process" ; return 0 ; }

    urlstat_update "$@"
    return $?

  } || {

    urlstat_init "$@"
    return $?
  }
}

urlstat_checkall()
{
  test -n "$Init_Tags" || Init_Tags="$package_lists_contexts_default"
  test -z "$update" -o -n "$urlstat_check_update" || urlstat_check_update=$update
  test -z "$process" -o -n "$urlstat_update_process" || urlstat_update_process=$process

  urlstat_checkall_inner()
  {
    test -z "$urlstat_file" ||
      note "URL-Id checking from '$urlstat_file': '$1' '$Init_Tags'"
    urlstat_src= urlstat_check "$1" $Init_Tags || {
      echo "urlstat:checkall:inner:$1:$Init_Tags" | tr -c 'a-z0-9:' ':' >>"$failed"
    }
  }
  p= s= act=urlstat_checkall_inner foreach_do "$@"
}

# Parse statusdir index file line for {PREFNAME}$id (from env, see urlstat-file-env)
# Provide ctx arg to parse descriptor iso. primary context (if func exists)
urlstat_entry() # URI-Ref
{
  test -n "$urlstat_src" || urlstat_entry_init "$1"
  test -n "$2" || set -- "$1" "$URLSTAT_TAB"
  url_re="$(match_grep "$1")"
  urlstat_line="$( $ggrep -m 1 -n "^[0-9 +-]*\b$url_re\\ " "$2" )"
  urlstat_entry_parse "$urlstat_line"
  urlstat_parse_std_descr $stat
}

urlstat_entry_defaults()
{
  false
}

urlstat_entry_env()
{
  urlstat_src=
  urlstat_entry=
  stat=
  status=
  ctime=
  btime=
  mtime=
  ltime=
  record=
  uriref=
  title=
  tags=
}

urlstat_entry_exists () # ~ <URI> [LIST]
{
  test -n "$urlstat_src" || urlstat_entry_init "$1"
  test -n "$2" || set -- "$1" "$URLSTAT_TAB"
  p_="$(match_grep "$1")"
  $ggrep -q "^[0-9 +-]*\b$p_\\ " "$2"
}

urlstat_entry_fetch() # <URI-Ref>
{
  { urlstat_entry "$1" && test -n "$status"
  } || error "Error parsing" 1
}

urlstat_entry_init () # ~ <URL>
{
  urlstat_entry_env
  sha1ref=$(printf -- "%s" "$1" | sha1sum - | cut -d ' ' -f 1)
  md5ref=$(printf -- "%s" "$1" | md5sum - | cut -d ' ' -f 1)
  urlstat_src="$1"
}

# Parse urlstat index file line
urlstat_entry_parse() # Tab-Entry
{
  # Split grep-line number from rest
  lineno="$(echo "$1" | cut -d ':' -f 1)"
  entry="$(echo "$1" | cut -d ':' -f 2-)"
  export lineno entry

  # Split rest into three parts (see urlstat format), first stat descriptor part
  stat="$(echo "$entry" | grep -o '^[0-9 +-]*' )"
  record="$(echo "$entry" | sed 's/^[^_A-Za-z]*//' )"
  debug "Parsing descriptor '$stat' and record '$record'"

  # Then ID and title, and rest

  uriref="$(echo "$record"|cut -d' ' -f1)"
  title="$(echo "$record"|cut -d' ' -f2-|$gsed 's/^\([^[+@<]*\).*$/\1/'|normalize_ws)"
  tags_raw="$(echo "$record"|cut -d' ' -f2-|$gsed 's/^[^\[+@<]*//'|normalize_ws)"
  tags="$(echo "$tags_raw"|$ggrep -o '^[^+@]*'|normalize_ws)"

  export stat record uriref title tags
}

urlstat_entry_status () #
{
  case "${status:-}" in -|0 ) true ;; * ) false ;; esac || { r=$?
    test ${quiet:-0} -eq 1 ||
        $LOG "fail" "" "Status: $status" "$uriref"
    test ${keep_going:-0} -eq 1 || return $r
  }
}

urlstat_entry_validate ()
{
  uriref-cli.py -sq absolute "$uriref" || { r=$?
    test ${quiet:-0} -eq 1 ||
        $LOG "fail" "" "Invalid reference" "$uriref"
    test ${keep_going:-0} -eq 1 || return $r
  }
}

urlstat_entry_update()
{
  false # TODO:
}

urlstat_exists () # <URI-Ref> [<URL-List>]
{
  local r=; grep_f=-q urlstat_grep "$@" || { r=$?
    $LOG "error" "" "No such urlstat reference" "$*"; return $r
  }
}

# Return matching record(s); filter by tags
urlstat_fetch ()  # [ <URI-Ref> | <Glob> ] [<Tags>]
{
  local ref glob
  # Proc first arg: either ref or glob
  { test ${is_grep:-0} -eq 0 -a \( $# -eq 0 -o -z "${1-}" \) || fnmatch "*\**" "$1"
  } && glob="${1:-"*"}" || ref="$1"
  test $# -eq 0 || shift

  {
    test -n "${ref-}" && {
      urlstat_grep "$ref" || return
    } || {
      urlstat_tab "$glob" || return
    }
  } | { test $# -gt 0 && {
        urlstat_filter "$@" || return
      } || cat
  }
}

urlstat_foreach () # <URI-Ref> [<Tags>]
{
  stb_act=$urlstat_act stattab_foreach "$@"
}

urlstat_filter () # <Tags>...
{
  local pl; while test $# -gt 0
  do
    case "$1" in
        "@"* ) pl="${pl-}${pl:+" | "}grep ' $1\\( \\|$\\)'" ;;
        "!@"* ) pl="${pl-}${pl:+" | "}grep -v ' ${1:1}\\( \\|$\\)'" ;;
        * ) return 98 ;;
    esac
    shift
  done
  test -n "${pl-}" || return 99
  eval $pl
}

urlstat_grep () # <URI-Ref> [<URL-List>]
{
  test -n "${2-}" || set -- "$1" "$URLSTAT_TAB"
  stattab_grep "$1" id "$2"
}

urlstat_import_diigo()
{ TODO
}

urlstat_import_shaarli()
{ TODO
}

urlstat_import_google()
{ TODO
}

urlstat_import_chrome()
{ TODO
}

# Generate line and append entry to statusdir index file
urlstat_init() # URI-Ref [Init-Tags]
{
  note "Initializing $1"
  test -n "$urlstat_src" || urlstat_entry_init "$1"
  test -z "$new_status" || status="$new_status"
  test -z "$new_ctime" || ctime="$new_ctime"
  test -z "$new_btime" || btime="$new_btime"
  test -z "$new_ltime" || ltime="$new_ltime"
  test -z "$new_mtime" || mtime="$new_mtime"
  test -z "$new_title" || title="$new_title"
  urlstat_init_fields "$@" | { tr '\n' ' ' ; echo ; } >> "$URLSTAT_TAB"
}

urlstat_init_fields() # URI-Ref [Init-Tags]
{
  note "Init fields '$*'"

  test -n "$urlstat_src" || urlstat_entry_init "$1"
  test -z "$1" || shift
  tags=$(urlstat_tags "$@") || status=1
  urlstat_descr
  echo "$urlstat_src"
  test -n "$title" && echo "$title"
  tag_default()
  {
    fnmatch "* $1 *" " $tags_raw " || echo "$1"
  }
  test -z "$1" || p= s= act=tag_default foreach_do "$@"
  echo "$tags_raw"
  fnmatch "* md5ref:* *" " $tags_raw " || echo md5ref:$md5ref
  fnmatch "* sha1ref:* *" " $tags_raw " || echo sha1ref:$sha1ref
  #test -n "$urlstat_file" &&  {
  #    fnmatch "* <$urlstat_file> *" " $tags " || echo "<$urlstat_file>"
  #  }
}

# List URI-Ref's
urlstat_list () # [<Glob>] [<URL-List>]
{
  test -n "${2-}" || set -- "${1-}" "$URLSTAT_TAB"
  stattab_list "$@"
}

urlstat_parse_std_descr()
{
  status=${1:-"-"}
  test -z "${2-}" || ctime=$(date_pstat $2)
  test -z "${3-}" || btime=$(date_pstat $3)
  test -z "${4-}" || ltime=$(date_pstat $4)
  test -z "${5-}" || mtime=$(date_pstat $5)
  export status ctime btime ltime mtime
}

urlstat_processall()
{
  urlstat_update_process=1 urlstat_check_update=1 urlstat_checkall "$@"
}

# See that entry exists, and show status.
urlstat_status () # <URI-Ref> [<Tags>]
{
  urlstat_act=urlstat_entry_status urlstat_foreach "$@"
}

# List entries; first argument is glob, converted to (grep) line-regex
urlstat_tab () # [<Glob>] [<URL-List>]
{
  test -n "${2-}" || set -- "${1-}" "$URLSTAT_TAB"
  stattab_tab "$@"
}

urlstat_updateall()
{
  urlstat_update_process=$process urlstat_check_update=1 urlstat_checkall "$@"
}

urlstat_url_contexts ()
{ TODO
}

urlstat_urlids ()
{ TODO
}

urlstat_validate ()
{
  test $# -gt 0 || set -- "" $urlstat_invalid
  urlstat_act=urlstat_entry_validate urlstat_foreach "$@"
}

#
