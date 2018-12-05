#!/bin/sh


docstat_lib_load()
{
  # index id names and pathnames, ie. see htd-components

  test -n "$STATUSDIR_ROOT" || STATUSDIR_ROOT=$HOME/.statusdir
  test -n "$DOCSTAT_TAB" || DOCSTAT_TAB=${STATUSDIR_ROOT}/index/docstat.list
  test -n "$DOCSTAT" || DOCSTAT=${STATUSDIR_ROOT}/tree/docstat
  test -d "$DOCSTAT" || mkdir "$DOCSTAT"
  test -n "$DOCSTAT_PREF" || DOCSTAT_PREF=$DOCSTAT/
  test -n "$DOC_EXT" || export DOC_EXT=.rst
}

docstat_init()
{
  test -e "$DOCSTAT_TAB" || {
    mkdir -p "$(dirname "$DOCSTAT_TAB")" || return
    touch "$DOCSTAT_TAB" || return
    mkdir -p "$DOCSTAT" || return
  }
}

docstat_file_env() # Doc-Path [New]
{
  test -n "$1" -a \( -e "$1" -o -n "$2" \) || error "DocStat-File-Env expected '$1'" 1
  note "Getting docfile-env for '$1'..."
  docstat_file_init "$1"
}

docstat_file_init()
{
  # Prefix trails with ':', replace path dir seps with double-colon too.
  test -n "$PREFNAME" || PREFNAME="$(htd_prefix "$(pwd)" | tr -s '/:' ':')"
  ext="$(filenamext "$1")"
  filename_baseid "$1"
  docstat_id="$id"
  docstat_src="$1"
}

# List entries; first argument is glob, converted to (grep) line-regex
docstat_list() # Match-Line
{
  test -n "$1" && {
    grep_f=
    re=$(compile_glob "$1")
    $ggrep $grep_f "$re" "$DOCSTAT_TAB" || return
  } || {
    read_nix_style_file "$DOCSTAT_TAB" || return
  }
}

# Lookup id retrieved from document or generated from document basename in
# statusdir index file. Id's are unique per PREFNAME, so the index can contain
# entries for one or all projects per host, user, etc.
docstat_exists() # Doc-Path
{
  test -n "$docstat_id" || docstat_file_env "$1"
  $ggrep -q "^[0-9a-z -]*\b${PREFNAME}$docstat_id\\ " "$DOCSTAT_TAB"
}

# Parse statusdir index file line
docstat_parse() # Tab-Entry
{
  # Split grep-line number from rest
  lineno="$(echo "$1" | cut -d ':' -f 1)"
  line="$(echo "$1" | cut -d ':' -f 2-)"
  export lineno line

  # Split line into three parts (see docstat format), first stat descriptor part
  stat="$(echo "$line" | grep -o '^[^_A-Za-z]*' )"
  _rest="$(echo "$line" | sed 's/[^_A-Za-z]*//' )"
  # Then ID and title
  docid="$(echo "$_rest" | cut -d ' ' -f 1)"
  title="$(echo "$_rest" | cut -d ' ' -f 2- | grep -o '^[^+@]*' | normalize_ws )"

  # And rest is primary ctx followed by anything left
  tags="$(echo "$_rest" | $gsed -e 's/^[^@]\+//g' )" # see todotxt tags

  export docstat_entry="$line"
  export stat docid title tags
}


# Parse statusdir index file line for {PREFNAME}$id (from env, see docstat-file-env)
# Provide ctx arg to parse descriptor iso. primary context (if func exists)
docstat_entry() # Doc-Path
{
  test -n "$docstat_id" || docstat_file_env "$1"
  docstat_parse "$( $ggrep -m 1 -n "^[0-9a-z -]*\b${PREFNAME}$docstat_id\\ " "$DOCSTAT_TAB" )"
  docstat_try_or_default_parse_stat
}

docstat_fetch() # Doc-Path
{
  { docstat_entry "$1" && test -n "$mtime"
  } || error "Error parsing" 1
}

docstat_try_or_default_parse_stat() # [Primary-Ctx]
{
  docstat_primctx "$1"
  # XXX: cleanup
  #test -n "$1" || set -- $tags

  # But fall-back to std descriptor if no function matches
  func_exists docstat_parse_${primctx_id}_descr &&
      std_info "Parsing stat fields as '$primctx'" || {
        std_info "No stat fields for '$primctx', using std"
        primctx=std
      }
  docstat_parse_${primctx_id}_descr $stat
}

# Generate line and append entry to statusdir index file
docstat_init() # Doc-Path
{
  note "Initializing $1"
  test -n "$docstat_id" || docstat_file_env "$1"
  {
    docstat_init_fields_$ext "$1"
  } | { tr '\n' ' ' ; echo ; } >> "$DOCSTAT_TAB"
}

docstat_init_fields_rst() # Doc-Path
{
  test -n "$docstat_id" || docstat_file_env "$1"
  std_info "Initializing index fields (rst format) for '$docstat_id'"
  warnings="$DOCSTAT/$PREFNAME$id.warnings" \
  warning_level=2 \
    du_getxml "$1" || error "Processing docfile '$1'" 1
  # Output lines with descriptor and other entry fields
  docstat_descr
  echo "$PREFNAME$id"
  debug "Fetch '$ext' format fields for '$docstat_src'"
  ${ext}_doc_title "$1" || echo
  docstat_${ext}_tags "$1"
}

# Get lines to initia stat descr for
docstat_descr() # [Prim-Ctx]
{
  docstat_primctx "$1"

  # fall-back to std status descriptor if no function matches primctx
  func_exists docstat_init_${primctx_id}_descr && {
      std_info "Initializing stat fields as '$primctx' for '$docstat_src'"
    } || {
      std_info "No initializer '$primctx' for '$docstat_src', using std"
      vid=std
    }

  docstat_init_${vid}_descr
}

# Determine primary context by looking at doc-path and using package_*
docstat_primctx() # [Prim-Ctx]
{
  # If no parsed tags in env, look at PWD; first for mapping
  test -n "$1" -o -z "$docstat_src" || {
    docstat_srcdir="$(dirname "$docstat_src")"

    # Primary context and more, by mapping relative dir from document path
    # NOTE: relative, local directory path only required to get correct map
    set -- "$( package_lists_contexts_map "$docstat_src" )"
  }

  # Else if PWD basename is capitalized name or blank Id
  test -n "$1" -o -z "$docstat_src" || {
    fnmatch "[A-Z_]*" "$docstat_srcdir" && set -- "@$docstat_srcdir" || true
  }

  # Else use package default, or fallback to static default
  test -n "$1" || set -- $package_lists_contexts_std
  test -n "$1" || set -- @Std

  export primctx="$1"

  # Make ID of first tag (without metachars)
  upper=0 mkvid "$(echo "$primctx" | cut -c2-)"

  export primctx_id="$vid"

  export tags="$(echo "$* $tags" | words_to_lines | sort -u |
      lines_to_words | normalize_ws_str)"

  note "docstat: Prim-Ctx: Tags: $tags"
}


# Replace docid line with freshly generated data. This will re-use existing
# docstat-entry env
docstat_update() # Doc-Path
{
  test -e "$1" -o -n "$docstat_src" || error "docstat-ptags: file required: $1" 1
  test -n "$docstat_id" && set -- "$docstat_src" || docstat_file_env "$1"
  test -n "$docstat_entry" || docstat_entry "$1"
  test -n "$line" || error "No entry found for '$docstat_id'" 1
  newline="$(docstat_init_fields_$ext "$1" | normalize_ws )"
  file_replace_at "$DOCSTAT_TAB" "$line" "$newline"
}

# Update status descriptor
docstat_extdescr() # Doc-Path [Primary-Ctx]
{
  test -e "$1" -o -n "$docstat_src" || error "docstat-ptags: file required: $1" 1
  test -n "$docstat_id" && set -- "$docstat_src" || docstat_file_env "$1"
  test -n "$docstat_entry" || docstat_entry "$1"
  newline="$(echo "$(docstat_descr "$2") $docid $title $tags" | normalize_ws)"
  file_replace_at "$DOCSTAT_TAB" "$line" "$newline"
}

# Update title
docstat_extitle() # Doc-Path [Primary-Ctx]
{
  test -e "$1" -o -n "$docstat_src" || error "docstat-ptags: file required: $1" 1
  test -n "$docstat_id" && set -- "$docstat_src" || docstat_file_env "$1"
  test -n "$docstat_entry" || docstat_entry "$1"
  newline="$(echo "$stat $docid $(${ext}_doc_title "$1") $tags" | normalize_ws)"
  file_replace_at "$DOCSTAT_TAB" "$line" "$newline"
}

# Update tag
docstat_extags() # Doc-Path [Primary-Ctx]
{
  test -e "$1" -o -n "$docstat_src" || error "docstat-ptags: file required: $1" 1
  test -n "$docstat_id" && set -- "$docstat_src" || docstat_file_env "$1"
  test -n "$docstat_entry" || docstat_entry "$1"
  newline="$(echo "$stat $docid $title $(${ext}_doc_tags "$1")" | normalize_ws)"
  file_replace_at "$DOCSTAT_TAB" "$line" "$newline"
}

# Reset primary context
docstat_ptags() # Doc-Path [Primary-Ctx]
{
  test -e "$1" -o -n "$docstat_src" || error "docstat-ptags: file required: $1" 1
  test -n "$docstat_id" && set -- "$docstat_src" || docstat_file_env "$1"
  test -n "$docstat_entry" || docstat_entry "$1"
  entry_tags="$tags"
  docstat_primctx "$2"
  tags="$primctx $( echo "$entry_tags $tags" | words_to_lines | sort -u | grep -vF "$primctx" | lines_to_words )"
  newline="$(echo "$stat $docid $title $tags" | normalize_ws)"
  file_replace_at "$DOCSTAT_TAB" "$line" "$newline"
}


# Fetch by docid and check mtime; update if file changed. Or create new entry
# This only sets docstat-file-env if not set already

docstat_check() # Doc-Path
{
  test -n "$docstat_id" || docstat_file_env "$1"
  test -n "$1" || set -- "$docstat_src"
  docstat_exists "$1" && {
    docstat_fetch "$1"
    docstat_check_update "$1" || return 0
    note "Updating $docid: $title stat:$status mtime:$mtime"
    docstat_entry "$1"
    docstat_update "$1"
    return $?

  } || {
    docstat_init "$1" || return
  }
}

docstat_check_update()
{
  test $mtime -lt $( filemtime "$1") -o "$status" != "0"
}


# Process one file
docstat_proc() # Doc-Path
{
  test -n "$docstat_id" || docstat_file_env "$1"
  test -n "$1" || set -- "$docstat_src"
  warnings="$DOCSTAT/tree/$PREFNAME$docstat_id.warnings" du_proc "$1"
}

# Execute docstat-proc or other subcmd for every doc-path. Without arguments
# lists all $DOC_EXTS files from SCM, and if '-' given whatever method can be
# used to provide doc-paths on stdin. Ie. see doc-find.
docstat_run() # [Action] [Doc-Path...]
{
  local sub="$1" ; shift 1 ;  test -n "$sub" || sub=proc
  func_exists "docstat_$sub" || error "No such function 'docstat_$sub'" 1

  docstat_run_inner() { docstat_file_env "$1" && docstat_$sub ; }
  test -n "$1" && {
    act=docstat_run_inner p= s= foreach_do "$@"
  } ||  {
    test -n "$package_list_documents" || package_list_documents=files-ext-re
    doc_list_local | act=docstat_run_inner p= s= foreach_do -
  }
}

# Process every file
docstat_procall() # [Doc-Path...]
{ docstat_run proc "$@" ; }

# Add or update every arg as document TODO: handle dirs
docstat_addall() # [Doc-Path...]
{ docstat_run check "$@" ; }


# Prepare new entry for filename and title
docstat_new() # Title-Descr...
{
  {
    docstat_descr
    echo "$PREFNAME$id"
    echo "$1"
    echo "$tags"
  } | { tr '\n' ' ' ; echo ; } >> "$DOCSTAT_TAB"
}


# XXX: slow duplicate ID check
docstat_checkidx()
{
  docstat_list "$@" | while read -r line
    do
      docstat_parse "0:$line"
      num="$( $ggrep -n "^[0-9a-z -]*\b$docid\\ " "$DOCSTAT_TAB" | count_lines )"
      test "$num" = "1" || warn "$docid"
    done
}


# Generate taglist, looking at document in package context
docstat_rst_tags() # Doc-Path
{
  test -n "$tags" || tags=""
  test -e "$1" || error "docstat-rst-tags: file required: $1" 1
  docstat_src="$1" docstat_primctx
  test -n "$primctx" || error "Primary context required" 1
  fnmatch "@*" "$primctx" || error "Context tags should start with '@'" 1
  echo "$tags"

  # Add contexts, concatenating nested Du/rSt definition list terms
  du_dl_terms_paths "$1" "$xml"
}

# Taglist has one-per line tag instances, updated every time docstat index changes
docstat_taglist()
{
  local taglist="$DOCSTAT/taglist.list"
  { test -e "$taglist" -a $(filemtime "$taglist") -gt $(filemtime "$DOCSTAT_TAB")
  } || {
    tasks_todotxt_tags "$DOCSTAT_TAB" | words_to_lines | sort -u > "$taglist"
  }
  cat "$taglist"
  note "$(count_lines "$taglist") tags (projects & contexts)"
}
