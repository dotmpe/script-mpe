#!/usr/bin/env bash

us-env -r user-script || ${us_stat:-exit} $?

info ()
{
  #context.sh grep statusdir-new:
  stat-grep.sh --full statusdir-new 2>/dev/null || true

  check --fast || echo "Check failed, use init"

  for path in ${STATUSDIR_ROOT}{index,cache,log,shell,tree}
  do
    [[ -h "$path" ]] ||
      >&2 echo "Path not a symlink yet $path"
  done
}

check ()
{
  case "${1-}" in
  ( --fast )
      assert-dirs STATUSDIR_ROOT METADIR_GLOBAL &&
      assert-dirpaths ${STATUSDIR_ROOT}{index,cache,log,shell,tree}
    ;;

    * ) failerr "$1?"
  esac
}

data ()
{
  : about "TODO manage some level of complex data"
  case "${1-}" in

  #( --create ) # ~ ~ <Key> ( <Command...> | <Format> )
  #    [[ ${3:1:1} == \' ]] && {
  #      data --create-object "${@:2}"
  #      return
  #    } ||
  #      data --create-output "${@:2}"
  #  ;;

  #( --create-object ) TODO "$FUNCNAME $*" ;;

  ( --create-output )
      #$sd_be set "${@:2}"
    ;;

  ( --list-prefix )
      $sd_be ls "${@:2}"
    ;;

  ( --del-key )
      $sd_be del "${@:2}"
    ;;

  ( --get-key )
      $sd_be get "${@:2}"
    ;;

  ( --set-key-value )
      $sd_be set "${@:2}"
    ;;

  ( --shell ) TODO "$FUNCNAME $*"
    ;;

    * ) failerr "${*}?"
  esac
}

init ()
{
  [[ -d "${STATUSDIR_ROOT}" ]] || {
    init-staffdir STATUSDIR_ROOT || return
  }
  local sub
  local -n trgt="statusdir_dir_conf[\$sub]"
  for sub in "${!statusdir_dir_conf[@]}"
  do
    [[ -d "${trgt:?Missing mapping value for $sub}" ]] && continue
    init-staffdir trgt || return
    [[ -h "${STATUSDIR_ROOT}${sub}" ]] && continue
    >&2 ln -vs "${trgt:?}" "${STATUSDIR_ROOT}${sub}" || return
  done
}

init-staffdir ()
{
  local -n ref=${1:?}
  : "${ref%/}"
  local bd=${_%/*} pref
  [[ -w "${ref}" ]] || pref="sudo "
  [[ -d "${ref}" ]] || {
    >&2 ${pref-}mkdir -vp "${ref}" &&
    >&2 ${pref-}chmod -v g+srwx "$ref" &&
    >&2 sudo chown -v root:staff "$ref"
  }
}

assert-dirpaths ()
{
  local path
  : "${*:?Directory path values expected}"
  for path
  do
    [[ -d "${path:?}" ]] && continue
    >&2 echo "Missing dir ${path@Q}"
    return 1
  done
}

assert-dirs ()
{
  local -n ref
  : "${*:?Directory path variable names expected}"
  for ref
  do
    [[ -d "${ref:?Value missing for ${!ref}}" ]] && continue
    >&2 echo "Missing dir ${ref@Q}"
    return 1
  done
}


#(($#)) || set -- info
statusdir_loadenv ()
{
  # Mapping for legacy statusdir subdirs to host paths
  declare -gA statusdir_dir_conf
  statusdir_dir_conf=(

    [index]="/var/local/statusdir"
    [cache]="/var/cache/statusdir"
    [log]="/var/log/statusdir"
    [tree]="/usr/share/statusdir"
  )

  declare -gA statusdir_user_conf
  statusdir_user_conf=(
    [name]=$USER
    [group]=staff
  )

  # Legacy and new export path
  : "${STATUSDIR_ROOT:=$HOME/.local/var/statusdir/}"
  : "${METADIR_GLOBAL:=${statusdir_dir_conf["index"]}}"

  us_part uc-cache &&
  #lib_require status statusdir statusdir-etcd
  declare -gA Statusdir__backend_types &&
  lib_load statusdir-etcd &&
  lib_init statusdir-etcd &&
  sd_be=sd_etcd || failerr "E$? backend init" || return
}


# Main entry (see user-script.sh for boilerplate)

! script_isrunning "statusdir" .sh || {
  user_script_load || failerr "E$? user-script-load" || exit

  # Pre-parse arguments
  script_defcmd=info
  user_script_defarg=defarg\ aliasargv

  # FIXME:
  eval "set -- $(user_script_defarg "$@")"

  script_run "$@"
}
