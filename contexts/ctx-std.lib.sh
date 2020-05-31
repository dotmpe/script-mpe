#!/bin/sh

#ctx_std_lib_load

ctx_std_lib_init() # Tags...
{
  test -z "$1" || note "std init: $*"
}


# Create std stat descriptor
docstat_init_std_descr()
{
  test -z "$du_result" && status=- || status=$du_result
  echo "$status"
  test -e "$docstat_src" && {
    filemtime "$docstat_src"
  } || echo -
}

# Parse stat descriptor
docstat_parse_std_descr()
{
  test -z "$1" || status=$1
  test -z "$2" || mtime=$2
  export status mtime
}


scr__std__tags()
{
  std_info "Tags for '$scr_src' '$scr_file'"
  test -z "$*" || {
    words_to_lines "$@"
  }
  echo "$scr_tags"
  echo "$scr_tags_raw"

  # Get tags for source-file
  test -z "$scr_file" || {
    fnmatch "to/*" "$scr_file" && {
      lib_load tasks
      tasks_hub_tags "$scr_file"
    }
    package_lists_contexts_map "$scr_file"
    echo "<$( htd prefix name "$scr_file" )>"
  }

  #tag_default()
  #{
  #  fnmatch "* $1 *" " $scr_tags_raw " || echo "$1"
  #}
  #test -z "$1" || p= s= act=tag_default foreach_do "$@"
  #echo "$scr_tags_raw"

  #fnmatch "* sha1sum:* *" " $scr_tags_raw " || echo sha1sum:$sha1sum

  scr_ref="$( htd prefix name "$scr_file" )"
  fnmatch "* <$scr_ref> *" " $scr_tags" || echo "<$scr_ref>"

  #return 1
}


htd_ctx__std__current()
{
  try_context_actions current base -- "$@"
}

htd_ctx__std__list()
{
  try_context_actions list base -- "$@"
}

htd_ctx__std__init()
{
  try_context_actions init base -- "$@"
}

htd_ctx__std__check()
{
  try_context_actions check base -- "$@"
}

htd_ctx__std__process()
{
  try_context_actions process base -- "$@"
}

htd_ctx__std__update()
{
  try_context_actions update base -- "$@"
}

htd_ctx__std__update_status()
{
  test -n "$failed" -a ! -e "$failed" ||
      error "status: failed env missing or already exists" 1
  local scm= scmdir=
  vc_getscm && {
    vc_status || {
      error "VC getscm/status returned $?"
    }

    htd_vcflow_summary

    git grep '(TODO\|FIXME\|XXX\|BUG\|NOTE)'

  } || { # not an checkout

    # Monitor paths
    # Using either lsof or update/access time filters with find we can list
    # files and other paths that a user has/has had in use.
    # There are plenty of use-cases based on this.

    # See htd open-paths for local paths, using lsof.
    # CWD's end up being recorded in prefixes. With these we can get a better
    # selection of files.

    # Which of those are projects
    note "Open-paths SCM status: "
    htd__current_paths | while read p
    do verbosity=3
      { test -e "$p" && pd exists "$p"
      } || continue
      $LOG "header3" "$p" "$( cd "$p" && vc.sh flags )" "" >&2
    done

    # Projects can still have a large amount of files
    # opened, or updated recently.

    # Create list of CWD, and show differences on subsequent calls
    #htd__open_paths_diff

    # FIXME: maybe something in status backend on open resource etc.
    #htd__recent_paths
    #htd__active

    stderr note "text-paths for main-docs: "
    # Check main documents, list topic elements
    {
      test ! -d "$JRNL_DIR" || EXT=$DOC_EXT htd__archive_path $JRNL_DIR
      htd__main_doc_paths "$1"
    } | while read tag path
    do
      test -e "$path" || continue
      htd tpath-raw "$path" || warn "tpath-raw '$path'..."
    done
  }

  #htd_tasks_scan

  # TODO:
  #  global, local services
  #  disks, annex
  #  project tests, todos
  #  src, tools

  # TODO: rewrite to htd proj/vol/..-status
  #( cd ; pd st ) || echo "home" >> $failed
  #( cd ~/project; pd st ) || echo "project" >> $failed
  #( cd /src; pd st ) || echo "src" >> $failed

  #htd git-remote stat

  test -s "$failed" -o -s "$errored" && stderr ok "htd stat OK" || true
}
htd_ctx__std__update_status_old()
{
  # Go to project root
  cd "$workspace/$prefix"

  # Gather counts and sizes for SCM dir
  { test -n "$scm" || vc_getscm
  } && {

    htd_ws_stats_update scm "
$(vc_stats . "        ")" || return 1

    test -d "$workspace/$prefix/.$scm/annex" && {

        htd_ws_stats_update disk-usage "
              annex: $( disk_usage .$scm/annex)
              scm: $( disk_usage .$scm )
              (total): $( disk_usage )
              (date): $( date_microtime )" || return 1

      } || {

        htd_ws_stats_update disk-usage "
              scm: $( disk_usage .$scm )
              (total): $( disk_usage )
              (date): $( date_microtime )" || return 1
      }

  } || {

    htd_ws_stats_update disk-usage "
          (total): $( disk_usage )
          (date): $( date_microtime )" || return 1
  }

  # Use project metadata for getting more stats
  package_file "$workspace/$prefix" || return 0

  # TODO: Per project static code analysis
  #package_lib_set_local "."
  #. $PACKMETA_SH

  #for name in $package_pd_meta_stats
  #do
  #  echo $name: $( verbosity=0 htd run $name 2>/dev/null )
  #done
}

htd_ctx__std__status()
{
  try_context_actions status base -- "$@"
}

htd_ctx__std__build()
{
  build -n "$package_std_build_bases" || package_std_build_bases=base
  try_context_actions build $package_std_build_bases -- "$@"
}

htd_ctx__std__test()
{
  test -n "$package_std_test_bases" || package_std_test_bases=base
  try_context_actions test $package_std_test_bases -- "$@"
}

htd_ctx__std__clean()
{
  test -n "$package_std_clean_bases" || package_std_clean_bases=base
  try_context_actions clean $package_std_clean_bases -- "$@"
}
