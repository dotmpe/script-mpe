#!/usr/bin/env bash


meta_sh__grp=meta
meta__grp=status
meta__libs=meta\ metadir
status__libs=status
#status__grp=user-script

meta_sh_attributes () # ~
{
  meta_attributes "$@"
}

meta_sh_attributes_sh () # ~
{
  meta_attributes_sh "$@"
}

meta_sh_check () # ~ \!TODO
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
    path=$(realpath -s "$1") &&
    attr=$(meta_attributes "$path") || return
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
meta_sh_context__grp=meta-sh


## User-script parts

#meta_sh_name=foo
#meta_sh_version=xxx
meta_sh_maincmds="attributes attributes-sh context help short version"
meta_sh_shortdescr='Track metadata'

meta_sh_loadenv ()
{
  user_script_loadenv || return
  script_part=${1:?} user_script_load groups || {
      # E:next means no libs found for given group(s).
      test ${_E_next:?} -eq $? || return $_
    }
  lk="$UC_LOG_BASE"
  $LOG notice "$lk:loadenv" "User script loaded" "[-$-] (#$#) ~ ${*@Q}"
}

# Main entry (see user-script.sh for boilerplate)

test -n "${uc_lib_profile:-}" || . "${UCONF:?}/etc/profile.d/bash_fun.sh"
uc_script_load user-script

! script_isrunning "meta.sh" || {
  export UC_LOG_BASE="${SCRIPTNAME}[$$]"
  user_script_load || exit $?

  # Pre-parse arguments
  script_defcmd=check
  #user_script_defarg=defarg\ aliasargv
  eval "set -- $(user_script_defarg "$@")"

  script_run "$@"
}
