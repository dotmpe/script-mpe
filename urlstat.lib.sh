#!/bin/sh


urlstat_lib_load()
{
  lib_assert statusdir || return
  test -n "${URLSTAT_TAB-}" || URLSTAT_TAB=${STATUSDIR_ROOT}index/urlstat.list
}

urlstat_lib_init()
{
  test "${urlstat_lib_init-}" = "0" && return
  test -e "$URLSTAT_TAB" || {
    touch "$URLSTAT_TAB" || return
  }
}

urlstat_load() # URL
{
  false
}

urlstat_entry_init() # URL
{
  urlstat_entry_env
  sha1ref=$(printf -- "%s" "$1" | sha1sum - | cut -d ' ' -f 1)
  md5ref=$(printf -- "%s" "$1" | md5sum - | cut -d ' ' -f 1)
  urlstat_src="$1"
}

stattab_entry_update()
{
  false
}

# List entries; first argument is glob, converted to (grep) line-regex
urlstat_list () # [Glob] [URLs.list]
{
  test -n "${2-}" || set -- "${1-}" "$URLSTAT_TAB"
  test -n "${1-}" && {
    test -n "${grep_f-}" || local grep_f=
    $ggrep $grep_f "$(compile_glob "$1")" "$2" || return
  } || {
    read_nix_style_file "$2" || return
  }
}

# List URI-Ref's
urlstat_urls () # [Glob] [URLs.list]
{
  urlstat_list "$@" | $gsed -E 's/^[0-9 +-]*([^ ]*).*$/\1/'
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
          test "$status" = "000" && status=2
          fnmatch "3*" "$status" && status=3
          fnmatch "4*" "$status" && status=4
          fnmatch "5*" "$status" && status=5
          #test -n "$title"
        ;;

      * ) ;; # XXX: urlstat unknown protocol
  esac
}

# Replace urlid line with freshly generated data. This will re-use existing
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

urlstat_entry_exists() # URI-Ref [LIST]
{
  test -n "$urlstat_src" || urlstat_entry_init "$1"
  test -n "$2" || set -- "$1" "$URLSTAT_TAB"
  p_="$(match_grep "$1")"
  $ggrep -q "^[0-9 +-]*\b$p_\\ " "$2"
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

# Parse urlstat index file line
urlstat_entry_parse() # Tab-Entry
{
  # Split grep-line number from rest
  lineno="$(echo "$1" | cut -d ':' -f 1)"
  entry="$(echo "$1" | cut -d ':' -f 2-)"
  export lineno entry

  # Split rest into three parts (see urlstat format), first stat descriptor part
  stat="$(echo "$entry" | grep -o '^[^_A-Za-z]*' )"
  record="$(echo "$entry" | sed 's/^[^_A-Za-z]*//' )"
  debug "Parsing descriptor '$stat' and record '$record'"

  # Then ID and title, and rest

  urlid="$(echo "$record"|cut -d' ' -f1)"
  title="$(echo "$record"|cut -d' ' -f2-|$gsed 's/^\([^[+@<]*\).*$/\1/'|normalize_ws)"
  tags_raw="$(echo "$record"|cut -d' ' -f2-|$gsed 's/^[^\[+@<]*//'|normalize_ws)"
  tags="$(echo "$tags_raw"|$ggrep -o '^[^+@]*'|normalize_ws)"

  export stat record urlid title tags
}

urlstat_parse_std_descr()
{
  test -z "$1" || status=$1
  test -z "$2" || ctime=$(date_pstat $2)
  test -z "$3" || btime=$(date_pstat $3)
  test -z "$4" || ltime=$(date_pstat $4)
  test -z "$5" || mtime=$(date_pstat $5)
  export status ctime btime ltime mtime
}

urlstat_entry_fetch() # URI-Ref
{
  { urlstat_entry "$1" && test -n "$status"
  } || error "Error parsing" 1
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
  urlid=
  title=
  tags=
}

urlstat_entry_defaults()
{
  false
}

urlstat_check() # URI-Ref [Tags]
{
  test -n "$urlstat_src" || urlstat_entry_init "$1"
  test -n "$1" || set -- "$urlstat_src"
  urlstat_entry_exists "$1" && {

    urlstat_entry_fetch "$1" || return $?
    note "Found $urlid"

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

urlstat_updateall()
{
  urlstat_update_process=$process urlstat_check_update=1 urlstat_checkall "$@"
}

urlstat_processall()
{
  urlstat_update_process=1 urlstat_check_update=1 urlstat_checkall "$@"
}

urlstat_diigo_import()
{ true
}

urlstat_shaarli_import()
{ true
}

urlstat_google_import()
{ true
}

urlstat_chrome_import()
{ true
}

#
