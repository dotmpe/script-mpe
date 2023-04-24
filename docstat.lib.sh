#!/bin/sh

# Statusfile for documents: record document status and other bits

docstat_lib_load()
{
  lib_assert statusdir || return
  # index id names and pathnames, ie. see htd-components

  test -n "${DOCSTAT_TAB-}" || DOCSTAT_TAB=${STATUSDIR_ROOT}index/docstat.list
  test -n "${DOCSTAT-}" || DOCSTAT=${STATUSDIR_ROOT}tree/docstat
  test -n "${DOCSTAT_PREF-}" || DOCSTAT_PREF=$DOCSTAT/
}

docstat_lib_init()
{
  test "${docstat_lib_init-}" = "0" && return
  test -e "$UCACHE/htd-docstat" || {
    mkdir -p "$UCACHE/htd-docstat"
  }
  test -e "$DOCSTAT_TAB" || {
    mkdir -p "$(dirname "$DOCSTAT_TAB")" && touch "$DOCSTAT_TAB" || return
  }
}

# Verbose docstat-file-init with user-sanity check
docstat_file_env() # Doc-Path [New]
{
  test -n "${1-}" || return 98
  test -e "$1" || warn "docstat-file-env: No such file '$*'"
  note "Getting docfile-env for '$1'..."
  docstat_file_init "$1"
}

# Env helper to prepare env for existing or new entry for given path. Prefix is
# resolved using UCONF:user/pathnames.tab (see prefix.lib)
docstat_file_init() # Path
{
  # Prefix trails with ':', replace path dir seps with double-colon too.
  test -n "${PREFNAME-}" || PREFNAME="$(prefix_resolve "$PWD" | tr -s '/:' ':')"
  docstat_fmt="$(filenamext "$1")"
  filename_baseid "$1"
  docstat_id="$id"
  docstat_src="$1"
  docstat_name="$(basename "$1" .$docstat_fmt)"
}

# List entries; first argument is glob, converted to (grep) line-regex
docstat_list() # [anchor_{start,end}] [grep_f] ~ [Glob-Match]
{
  test $# -le 1 || return 98
  test -n "${1-}" && {
    re="${anchor_start+"^"}$(compile_glob "$1")${anchor_end+"$"}"
    $ggrep ${grep_f-} "$re" "$DOCSTAT_TAB" || return
  } || {
    read_nix_style_file "$DOCSTAT_TAB" || return
  }
}

docstat_count () # [Glob]
{
  docstat_list "$@" | count_lines
}

# Lookup id retrieved from document or generated from document basename in
# statusdir index file. Id's are unique per PREFNAME, so the index can contain
# entries for one or all projects per host, user, etc.
docstat_exists() # Doc-Path
{
  test -n "${docstat_id-}" || docstat_file_env "$1"
  $ggrep -q "^[0-9a-z -]*\b${PREFNAME}$docstat_id\\ " "$DOCSTAT_TAB"
}

# Parse statusdir index file line
docstat_parse() # Tab-Entry
{
  # Split grep-line number from rest
  lineno="$(echo "$1" | cut -d ':' -f 1)"
  line="$(echo "$1" | cut -d ':' -f 2-)"

  # Split line into three parts (see docstat format), first stat descriptor part
  stat="$(echo "$line" | grep -o '^[^_A-Za-z]*')"
  _rest="$(echo "$line" | sed 's/^[^_A-Za-z]*//')"

  # Then ID and title
  docid="$(echo "$_rest" | cut -d ' ' -f 1)"
  _rest="$(echo "$_rest" | cut -d ' ' -f 2-)"

  tags="$(echo "$_rest" | grep -o '[+@][^ ]*')"
  _rest="$(echo "$_rest" | sed -e 's/[+@][^ ]\+//g')" # see todotxt tags

  meta="$(echo "$_rest" | grep -Po '[^ :]+:[^ $]+')"
  eval $( echo $meta | tr ':' '=' )
  _rest="$(echo "$_rest" | sed -e 's/[^ :]\+:[^ $]\+//g')"

  title="$(echo "$_rest" | normalize_ws)"

  docstat_entry="$line"
}


# Parse statusdir index file line for {PREFNAME}$id (from env, see docstat-file-env)
# Provide ctx arg to parse descriptor iso. primary context (if func exists)
docstat_entry() # [Doc-Path]
{
  test -n "${docstat_id-}" || docstat_file_env "$1" || return
  docstat_parse "$( $ggrep -m 1 -n "^[0-9a-z -]*\b${PREFNAME}$docstat_id\\ " "$DOCSTAT_TAB" )" && docstat_try_or_default_parse_stat
}

# Verbose call to docstat-entry, (user) sanity check
docstat_fetch() # Doc-Path
{
  { docstat_entry "$1" && test -n "${mtime-}"
  } || $LOG error :docstat:fetch "Error parsing <$? $1>" $?
}

docstat_try_or_default_parse_stat() # [Primary-Ctx]
{
  # XXX: cleanup, see also docstat-descr
  #test -n "$1" || set -- $tags
  docstat_primctx "${1-}" # std dev base main ci...

  # But fall-back to std descriptor if no function matches
  func_exists docstat_parse_${primctx_id}_descr &&
      std_info "Parsing stat fields as '$primctx'" || {
        std_info "No stat fields for '$primctx', using std"
        primctx_id=std
        primctx_id=doc
      }
  docstat_parse_${primctx_id}_descr $stat
}

# Generate line and append entry to statusdir index file
docstat_init() # Doc-Path
{
  $LOG note :docstat "Initializing $1"
  test -n "${docstat_id-}" || docstat_file_env "$1"
  {
    docstat_init_fields_$docstat_fmt "$1"
  } | { tr '\n' ' ' ; echo ; } >> "$DOCSTAT_TAB"
}

docstat_init_fields_rst() # Doc-Path
{
  test -n "${docstat_id-}" || docstat_file_env "$1"
  std_info "Initializing index fields (rst format) for '$docstat_id'"
  local warnings="$DOCSTAT/$PREFNAME$id.warnings" xml docstat_path du_result
  docstat_path="$(realpath "$docstat_srcdir")"
  xml=$UCACHE/htd-docstat/${docstat_path////_}-$docstat_name.xml
  warning_level=2 \
    du_getxml "$1" "$xml" ||
    $LOG error :docstat "E$? Processing docfile '$1', see <$warnings>" "" 1
  status="${du_result:-"$status"}"
  # Output lines with descriptor and other entry fields
  docstat_descr
  echo "$PREFNAME$id"
  debug "Fetch '$docstat_fmt' format fields for '$docstat_src'"
  ${docstat_fmt}_doc_title "$1" || echo
  docstat_${docstat_fmt}_tags "$1" "$xml"
  echo "fmt:${fmt:-$docstat_fmt}"
}

# Get lines to initia stat descr for
docstat_descr() # [Prim-Ctx]
{
  docstat_primctx "${1-}"

  # fall-back to std status descriptor if no function matches primctx
  func_exists docstat_init_${primctx_id}_descr && {
      std_info "Initializing stat fields as '$primctx' for '$docstat_src'"
    } || {
      std_info "No initializer '$primctx' for '$docstat_src', using std"
      primctx_id=std
    }

  docstat_init_${primctx_id}_descr
}

# Determine primary context by looking at doc-path and using package_*
docstat_primctx() # [Prim-Ctx]
{
  # If no parsed tags in env, look at PWD; first for mapping
  test -n "${1-}" -o -z "${docstat_src-}" || {
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

  export tags="$(echo "$*${tags+" "}${tags-}" | words_to_lines | sort -u |
      lines_to_words | normalize_ws_str)"

  $LOG note :docstat:primctx "Primary context" "$tags"
}


# Replace docid line with freshly generated data. This will re-use existing
# docstat-entry env
docstat_update() # Doc-Path
{
  test $# -le 1 || return 98
  test -e "${1-}" -o -n "${docstat_src-}" ||
      error "docstat-update: file required: $1" 1
  test -n "${docstat_id-}" && set -- "$docstat_src" || docstat_file_env "$1"
  test -n "${docstat_entry-}" || docstat_entry "$1"
  test -n "${lineno-}" || error "No entry found for '$docstat_id'" 1
  newline="$(docstat_init_fields_$docstat_fmt "$1" | normalize_ws )"
  file_replace_at "$DOCSTAT_TAB" "$lineno" "$newline"
}

# Update status descriptor
docstat_fmtdescr() # Doc-Path [Primary-Ctx]
{
  test $# -le 2 || return 98
  test -e "${1-}" -o -n "${docstat_src-}" || error "docstat-extdescr: file required: $1" 1
  test -n "${docstat_id-}" && set -- "$docstat_src" || docstat_file_env "$1"
  test -n "${docstat_entry-}" || docstat_entry "$1"
  test -n "${lineno-}" || error "No entry found for '$docstat_id'" 1
  newline="$(echo "$(docstat_descr "$2") $docid $title $tags" | normalize_ws)"
  file_replace_at "$DOCSTAT_TAB" "$lineno" "$newline"
}

# Update title
docstat_fmtitle() # Doc-Path [Primary-Ctx]
{
  test $# -le 2 || return 98
  test -e "$1-}" -o -n "${docstat_src-}" || error "docstat-extitle: file required: $1" 1
  test -n "${docstat_id-}" && set -- "$docstat_src" || docstat_file_env "$1"
  test -n "${docstat_entry-}" || docstat_entry "$1"
  test -n "${lineno-}" || error "No entry found for '$docstat_id'" 1
  newline="$(echo "$stat $docid $(${docstat_fmt}_doc_title "$1") $tags" | normalize_ws)"
  file_replace_at "$DOCSTAT_TAB" "$lineno" "$newline"
}

# Update tag
docstat_fmtags() # Doc-Path [Primary-Ctx]
{
  test $# -le 2 || return 98
  test -e "${1-}" -o -n "${docstat_src-}" || error "docstat-extags: file required: $1" 1
  test -n "${docstat_id-}" && set -- "$docstat_src" || docstat_file_env "$1"
  test -n "${docstat_entry-}" || docstat_entry "$1"
  test -n "${lineno-}" || error "No entry found for '$docstat_id'" 1
  newline="$(echo "$stat $docid $title $(${docstat_fmt}_doc_tags "$1")" | normalize_ws)"
  file_replace_at "$DOCSTAT_TAB" "$lineno" "$newline"
}

# Reset primary context
docstat_ptags() # Doc-Path [Primary-Ctx]
{
  test $# -le 2 || return 98
  test -e "${1-}" -o -n "${docstat_src-}" || error "docstat-ptags: file required: $1" 1
  test -n "${docstat_id-}" && set -- "$docstat_src" || docstat_file_env "$1"
  test -n "${docstat_entry-}" || docstat_entry "$1"
  test -n "${lineno-}" || error "No entry found for '$docstat_id'" 1
  entry_tags="$tags"
  docstat_primctx "$2"
  tags="$primctx $( echo "$entry_tags $tags" | words_to_lines | sort -u | grep -vF "$primctx" | lines_to_words )"
  newline="$(echo "$stat $docid $title $tags" | normalize_ws)"
  file_replace_at "$DOCSTAT_TAB" "$lineno" "$newline"
}


# Fetch by docid and check mtime; update if file changed. Or create new entry
# This only sets docstat-file-env if not set already

docstat_assert_entry () # Doc-Path
{
  test -n "${docstat_id-}" || docstat_file_env "$1" || return
  test -n "${1-}" || set -- "$docstat_src"
  docstat_exists "$1" && {
    docstat_fetch "$1" || return
    docstat_check_update "$1" || return 0
    note "Updating $docid: $title stat:$status mtime:$mtime"
    #docstat_refresh || return
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

# Process one or all file(s) (docstat-src) with du-proc
docstat_proc () # [Doc-Path]
{
  test -n "${docstat_id-}" || docstat_file_env "$1"
  test -n "${1-}" || set -- "$docstat_src"
  warnings="$DOCSTAT/$PREFNAME$docstat_id.warnings" du_proc "$1"
}

# Execute docstat-proc or other subcmd for every doc-path. Without doc-paths
# given will list all files with $DOC_EXTS from SCM. With '-' anything can be
# provided on stdin method can be. Or '--' or '-*' will use files-local-load
# to select a source-set and optionally provide arguments (ie. globs) to the
# source-set-handler. E.g. -tracked "*.txt".
docstat_run () # [ACTION] [DOC-PATH...| -[SRC-SET|-] DOC-GLOB]
{
  local sub="${1-}" ; test $# -eq 0 || shift 1 ;  test -n "$sub" || sub=proc
  func_exists "docstat_$sub" || error "No such function 'docstat_$sub'" 1

  docstat_run_inner() { docstat_file_env "$1" && docstat_$sub ; }

  test $# -gt 0 -a \( "${1-:0:1}" != "-" -o "$1" = "-" \) && {
    act=docstat_run_inner p= s= foreach_do "$@"
    return $?
  } ||  {
    local srcset=${1:-"-default"}
    test $# -eq 0 || shift
    files_list $srcset "$@" | act=docstat_run_inner p= s= foreach_do -
  }
}

# List info
docstat_info_local () # ~ [Doc-Path... | -- Glob]
{ docstat_run local_docinfo "$@" ; }

# Process every file
docstat_procall () # ~ [Doc-Path... | -- Glob]
{ docstat_run proc "$@" ; }

# Add or update every arg as document TODO: handle dirs
# Without arguments use doc-list-local
docstat_addall () # ~ [Doc-Path... | -- Glob]
{ docstat_run assert_entry "$@" ; }


# Prepare new entry for filename and title
docstat_new () # Title-Descr...
{
  {
    docstat_descr
    echo "$PREFNAME$id"
    echo "$1"
    echo "$tags"
  } | { tr '\n' ' ' ; echo ; } >> "$DOCSTAT_TAB"
}


# Generate taglist, looking at document in package context
docstat_rst_tags() # Doc-Path
{
  test -n "${tags-}" || tags=""
  test -e "${1-}" || error "docstat-rst-tags: file required: $1" 1
  docstat_src="$1" docstat_primctx
  test -n "$primctx" || error "Primary context required" 1
  fnmatch "@*" "$primctx" || error "Context tags should start with '@'" 1
  {
    echo "$tags"

    # Add contexts, concatenating nested Du/rSt definition list terms
    du_dl_terms_paths "$1"

  } | words_to_lines | remove_dupes
}

# Taglist has one-per line tag instances, updated every time docstat index changes
docstat_taglist() #
{
  local taglist="$DOCSTAT/taglist.list"
  { test -s "$taglist" &&
      test $(filemtime "$taglist") -gt $(filemtime "$DOCSTAT_TAB")
  } || {
    {
      tasks_todotxt_tags "$DOCSTAT_TAB" | words_to_lines | sort -u > "$taglist"
    } || {
      $LOG error :docstat:taglist "Failed refreshing taglist" "$taglist"
      return
    }
    $LOG info :docstat:taglist "Refreshed taglist"
  }
  cat "$taglist"
  note "$(count_lines "$taglist") tags (projects & contexts)"
}

docstat_local_docinfo () # [DOC-FILE-INIT] ~ [FMT]
{
  local line
  # XXX: fetch not returning proper status code, here it works:
  line="$( $ggrep -m 1 -n "^[0-9a-z -]*\b${PREFNAME}$docstat_id\\ " "$DOCSTAT_TAB" )" || {
    warn "No entry $docstat_src:$docstat_id:$docstat_fmt"
    return
  }
  docstat_parse "$line"
  #docstat_entry
  _docstat_doc_info_env
}

docstat_info ()
{
  docstat_list | docstat_doc_info
}

docstat_doc_info ()
{
  while read -r line; do docstat_parse "0:$line" || continue
      _docstat_doc_info_env; done
}

_docstat_doc_info_env ()
{
  #docstat_fmt="$(filenamext "$1")"
  #filename_baseid "$1"
  test -n "$docid" || {
    warn "No docid $docstat_src:$docstat_id:$docstat_fmt: $lineno:$line"
    return
  }
  echo "$DOCSTAT_TAB:$lineno:$docid $stat $title $tags"
  #pref=$(echo "$docid" | cut -d ':' -f 1)
  #name=$(echo "$docid" | cut -d ':' -f 2)
  #dir=$(prefix_expand "$pref")
  #echo "$DOCSTAT_TAB:$lineno:$docid $pref $dir $name $stat $title $tags"
  #echo "($stat) $DOCSTAT_TAB:$lineno: $docid $title $tags"
}

docstat_check () # [Index-Glob]
{
  docstat_list "$@" | docstat_doc_check
}

# XXX: slow duplicate ID check
docstat_doc_check ()
{
  while read -r line; do docstat_parse "0:$line" || continue;
      _docstat_doc_check_env; done
}

_docstat_doc_check_env ()
{
  num="$( $ggrep -n "^[0-9a-z -]*\b$docid\\ " "$DOCSTAT_TAB" | count_lines )"
  test "$num" = "1" || warn "$docid"
}

docstat_err () #
{
  docstat_list | grep -v '^0 '
}

docstat_ok () #
{
  docstat_list | grep '^0 '
}

#
