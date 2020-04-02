#!/bin/sh


# See also docstat-list XXX: see also doc-find, list from SCM etc.
htd_doc_list()
{
  doc_list_local
}

# Get log env, test for and copy from package-log-dir
req_logdir_env()
{
  test -n "$log" || {
    test -n "$package_name" || {
        package_lib_set_local .
        . "$PACKMETA_SH"
        note "Package: $package_name #$package_id v$package_version"
    }
    log="$package_log_dir"
  }
  test -n "$log" -a -d "$log" || error "package log env expected ($log)" 1
}

# Frontend for -htd-doc-query-or-create-or-edit, see htd-doc-new for info.
htd_doc_exists() # Title-Descr...
{
  lib_load context ctx-base
  query=1 _htd_doc_query_or_create_or_edit "$@"
}

# Frontend for -htd-doc-query-or-create-or-edit, see htd-doc-new for info.
htd_doc_edit() # Title-Descr...
{
  lib_load context ctx-base
  edit=1 _htd_doc_query_or_create_or_edit "$@"
}

# Build a new permalog entry, ie. a docpath that includes a date and that will
# exists indefinitely. Its content never changes, or not for a significant time.
#
# rst title and created fields builtin. enters entry into docstat, and adds
# permalog pseudo-directive to journal:today file.
#
# Frontend for -htd-doc-query-or-create-or-edit
htd_doc_new() # Title-Descr...
{
  lib_load context ctx-base
  create=1 edit=1 _htd_doc_query_or_create_or_edit "$@"
}


# Get archived path for given title-descr, create and/or start editor for path,
# this wraps htd-doc-file and doc-title-id for Title-Descr to doc-id.
_htd_doc_query_or_create_or_edit() # [query=] [create=] [edit=] ~ [Title-Descr...]
{
  test -n "$title_fmt" || title_fmt="$package_log_doctitle_fmt"
  test -z "$1" && {

    # No filename for archive-path, build unique title/docid from calendar day
    test -n "$now" &&
        title="$(date_fmt "$now" "$title_fmt")" ||
        title="$(date_fmt "" "$title_fmt")"
    htd_doc_file "%a-%g_w%V" "$title" || return $?

  } || {

    # Tags given, look for % to expand (with stftime)
    eval set -- $( for a in "$@"
        do
          test "$a" = "%default" && { $gdate +"\"$title_fmt\"" ; continue ; }
          fnmatch "*%*" "$a" && $gdate +"\"$a\"" || echo \"$a\"
        done | lines_to_words )
    doc_title_id "$@" || return $?
    htd_doc_file "$doc_id" "$($gdate +"$doc_title")"
  }
}


# Build path to document file, each argument corresponding to a topic or title,
# and being concatenated for document filename and title entry. But formatted
# according to use, with no arguments set to calendar day for [date].
#
# Without create or edit env settings then query=1.
# Otherwise ff query set then create=0 edit=0.
#
# TODO: unify package-permalog-method settings
htd_doc_file() # [date=now] [query=] [edit=] [create=] ~ [Title-Descr..]
{
  test -n "$1" || error "Name-Id required" 1
  test -n "$htd_doc_init_fields" || htd_doc_init_fields="title created"

  lib_load context ctx-base ctx-std

  #upper=0 mkvid "$package_permalog_method" ; method=$vid
  # doc_${method}_new "$@"

  # Parse pre-given filename to embed it in archive path
  fnmatch "*.*" "$1" && EXT=.$(filenamext "$1") ||  EXT="$DOC_EXT"

  # Process strftime placeholders before setting docid
  test -n "$now" &&
    docname="$(date_fmt "$now" "$(basename "$1" $EXT)")" ||
    docname="$($gdate +"$(basename "$1" $EXT)")"

  docstat_file_env "$docname" 1

  test -z "$query" -a -z "$create" -a -z "$edit" &&
      eval query=1 create=0 edit=0 || {
    trueish "$query" && eval create=0 edit=0
  }

  trueish "$create" && {
    docstat_exists && warn "Entry exists '$docstat_id'" 1
    std_info "Doc-New Name-Id: $docstat_id"
  }

  # Build strftime pathstr
  archive_path "$package_permalog_path/$1" "$now"
  note "Doc Path: $archive_path"

  # Create file and add docstat entry
  trueish "$create" && {
      mkdir -p "$(dirname "$archive_path")"
      touch "$archive_path"
  }
  req_logdir_env

  test -e "$archive_path" && {
    htd_rst_doc_create_update "$archive_path" "$2" $htd_doc_init_fields
  }
  trueish "$create" && {
    docstat_src="$archive_path" ext=$(echo "$EXT" | cut -c2-) docstat_new "$2"
  }
  note "c:$create q:$query e:$edit path: $archive_path"

  trueish "$query" && {

    test -e "$archive_path" || return
    echo $archive_path
    return
  }
  trueish "$edit" || return 0
  test -e "$archive_path" || return
  cabinet_permalog "$log/today.rst" "$docstat_id" "$archive_path"
  $EDITOR "$archive_path"
}

# Start EDITOR, after succesful exit cleanup generated files
htd_edit_and_update()
{
  test -e "$1" || error htd-edit-and-update-file 1

  eval $EDITOR $evoke "$@" || return $?

  htd_doc_cleanup_generated "$@"
}

htd_log_current()
{
  for ptag in yesterday today tomorrow week month year
  do
     set -- "$package_log/$ptag.rst"
     test -e "$1" || continue
     echo "$1"
     continue
     #docstat_rst_tags "$1"
     du_dl_terms_paths "$1"
  done
}

htd_doc_check()
{
  PREFNAME=
  doc_list_local | while read -r doc
    do
        ext="$(filenameext "$doc")"
        docstat_check "$doc"
    done
}
