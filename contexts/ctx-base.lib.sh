#!/bin/sh

htd_ctx__base__current()
{
  vc_getscm && {
    spwd=. vc_unversioned || return $?
    spwd=. vc_modified || return $?
  }
  test -d "$package_log" && {
    htd_log_current || return $?
  }
}

htd_ctx__base__check()
{
  test -n "$1" || set -- $package_pd_meta_checks
  test -n "$1" || error "No checks" 1

  # $package_pd_meta_method
  p= s= act=run_check foreach_do "$@"
}

htd_ctx__base__process()
{
  note "Base process '$*'"
  lib_load tasks
  tasks_package_defaults

  test -z "$package_pd_meta_tasks_hub" || {

    tags="$(htd__tasks_tags "$@" | lines_to_words ) $tags"

    note "Process Tags: '$tags'"
    htd_tasks_buffers $tags | grep '\.sh$' | while read scr
    do
      test -e "$scr" || continue
      test -x "$scr" || { warn "Disabled: $scr"; continue; }
    done
    for tag in $tags
    do
      scr="$(htd_tasks_buffers "$tag" | grep '\.sh$' | head -n 1)"
      test -n "$scr" -a -e "$scr" || continue
      test -x "$scr" || { warn "Disabled: $scr"; continue; }

      echo tag=$tag scr=$scr
      #grep $tag'\>' $todo_document | $scr
      # htd_tasks__at_Tasks process line
      continue
    done
  }
}

htd_ctx__base__status()
{
  local key=htd:status:$hostname:$(verbosity=0 htd__prefixes name $cwd)
  statusdir.sh exists $key 2>/dev/null || warn "No status recorded" 1
  statusdir.sh members $key | while read status_key
  do
    note "$status_key"
  done
}

htd_ctx__base__build()
{
  rm -f $(setup_tmpd)/htd-out
  htd__make build 2>1 | capture_and_clear
  echo Mixed output::
  echo
  cat $(setup_tmpd)/htd-out | sed  's/^/    /'
}

htd_ctx__base__clean()
{
  test -n "$1" || set -- .
  test -d "$1" || error "Dir expected '$?'" 1
  note "Checking $1 for things to cleanup.."

  local pwd=$(pwd -P) ppwd=$(pwd) spwd=. scm= scmdir=

  htd_clean_scm "$1"

  for localpath in $1/*
  do
    case "$localpath" in

      *.zip )
            htd__clean_unpacked "$localpath"
          ;;

      *.tar | *.tar.bz2 | *.tar.gz )
          ;;

      *.7z )
          ;;
    esac
  done

  for localpath in $1/*
  do
    test -f "$localpath" && {

      htd__file "$localpath"
    }
  done

  # Recurse
  for localpath in $1/*
  do
    test -d "$localpath" && {

      htd__clean "$localpath"
    }
  done

  htd__clean_empty_dirs
}

#ctx_bin__base__
