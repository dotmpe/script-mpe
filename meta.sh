#!/usr/bin/env bash


meta_sh_attributes ()
{
  meta_attributes "$@"
}

meta_sh_attributes_sh ()
{
  meta_attributes_sh "$@"
}

meta_sh_check ()
{
  $LOG warn : TODO check 1
}

meta_sh_context () # ~ [ <Paths...> ] # List attributes at paths and parents
{
  test $# -gt 0 ||
      eval "set -- ${meta_sh_default_leafs:-"\{.,\{main,index,default}.*}"}"

  declare -A metapaths

  local attr path
  while test $# -gt 0
  do
    path=$(realpath -s "$1")
    attr=$(meta_attributes "$path")
    test -z "$attr" ||
        metapaths[$path]=$attr
    while test "$path" != /
    do
      path=$(dirname "$path")
      test -n "${metapaths[$path]-unset}" || continue
      attr=$(meta_attributes "$path") || true
      metapaths[$path]=$attr
    done
    shift
  done

  for path in $(foreach "${!metapaths[@]}" | sort )
  do
    attr="${metapaths[$path]:-}"
    test -n "$attr" || continue
    echo "$path:"
    echo "$attr" | sed 's/^/  /'
  done
}


meta_sh_loadenv ()
{
  lib_load meta metadir &&
  lib_init meta metadir
}


## User-script parts

#context_sh_name=foo
#context_sh_version=xxx
context_sh_maincmds="attributes attributes-sh help short version"
context_sh_shortdescr='Track contexts'


# Main entry (see user-script.sh for boilerplate)

test -n "${uc_lib_profile:-}" || . "${UCONF:?}/etc/profile.d/bash_fun.sh"
uc_script_load user-script

! script_isrunning "meta.sh" || {
  user_script_load || exit $?

  # Pre-parse arguments

  script_defcmd=check
  #user_script_defarg=defarg\ aliasargv

  eval "set -- $(user_script_defarg "$@")"

  script_run "$@"
}
