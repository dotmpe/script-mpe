#!/usr/bin/env make.sh


# Script subcmd's funcs and vars

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




# Generic subcmd's

redmine_man_1__help="Usage help. "
redmine_spc__help="-h|help"
redmine_als___h=help
redmine__help()
{
  test -z "$dry_run" || note " ** DRY-RUN ** " 0
  choice_global=1 std__help "$@"
}




# Script main functions

MAKE-HERE

INIT_ENV="init-log strict 0 0-src 0-u_s 0-1-lib-sys 0-std ucache scriptpath box"

main-local
failed=

main-init

main-lib
  lib_load main meta box date doc table remote match std stdio || return
  local __load_lib=1
  INIT_LOG=$LOG lib_init || return

main-load
  test -n "$hostname" || hostname="$(hostname -s | tr 'A-Z' 'a-z')"

  test -n "${remote_host-}" || remote_host=dandy
  test -n "${remote_user-}" || remote_user=hari
  on_host ${remote_host-} || ssh_req $remote_host $remote_user
