#!/bin/sh

redmine_src=$_
test -z "$__load_lib" || set -- "load-ext"

set -e



redmine__custom()
{
  local custom_fields=$(setup_tmpf -custom_fields.tab)
  run_cmd "$remote_host" "redmine_meta.py custom-fields" > $custom_fields
  cat $custom_fields | sed -E 's/([0-9-]+\ )+//g'
}

redmine__projects()
{
  local projects=$(setup_tmpf -projects.tab)

  run_cmd "$remote_host" "redmine_meta.py projects" > $projects
  cat $projects | sed -E 's/([0-9-]+\ )+//g'
  note "$(count_lines $projects) projects at RDM $remote_host"
}

redmine__list()
{
  redmine__issues
}

redmine__issues()
{
  local issues=$(setup_tmpf -issues.tab)
  run_cmd "$remote_host" "redmine_meta.py issues" > $issues
  cat $issues | sed -E 's/([0-9-]+\ )+//g'
  note "$(count_lines $issues) issues at RDM $remote_host"
}


# Direct to DB. Careful!
redmine__db_sa()
{
  test -n "$flags" || flags="-v"
  test -n "$cmd" || cmd=stats
  dbref=$(redmine_meta.py print-db-ref)
  test -n "$dbref" || error dbref 1
  db_sa.py -d $dbref $flags $cmd redmine_schema
}


# Print schema stats
redmine__stats()
{
  cmd=stats redmine__db_sa
}


# Disregard local Py schema, print everything in DB schema
redmine__db_stats()
{
  flags="-v --database-tables"
  redmine__info
}



### Main


redmine_main()
{
  local scriptname=redmine base=$(basename $0 .sh) verbosity=5 \
    scriptpath="$(cd "$(dirname "$0")"; pwd -P)" \
    failed=

  redmine_init || exit $?

  case "$base" in

    $scriptname )

        test -n "$1" || set -- list

        redmine_lib || exit $?
        run_subcmd "$@" || exit $?
      ;;

    * )
        error "not a frontend for $base ($scriptname)" 1
      ;;

  esac
}

redmine_init()
{
  # XXX test -n "$SCRIPTPATH" , does $0 in init.sh alway work?
  test -n "$scriptpath"
  export SCRIPTPATH=$scriptpath
  . $scriptpath/util.sh
  util_init
  . $scriptpath/match.lib.sh
  . $scriptpath/box.init.sh
  box_run_sh_test
  lib_load main meta box data doc table remote
  # -- redmine box init sentinel --
}

redmine_lib()
{
  local __load_lib=1
  . $scriptpath/match.sh load-ext
  # -- redmine box lib sentinel --
  set --
}

redmine_load()
{
  test -n "$hostname" || hostname="$(hostname -s | tr 'A-Z' 'a-z')"

  test -n "$remote_host" || remote_host=dandy
  test -n "$remote_user" || remote_user=hari
  on_host $remote_host || ssh_req $remote_host $remote_user
}


# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )
  # Ignore 'load-ext' sub-command
  test -z "$__load_lib" || set -- "load-ext"
  case "$1" in load-ext ) ;; * )
    redmine_main "$@"
  ;; esac
;; esac


