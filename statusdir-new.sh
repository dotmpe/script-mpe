#!/usr/bin/env bash

(($#)) || set -- info

set -eETuo pipefail

# Mapping for legacy statusdir subdirs to host paths
declare -gA statusdir_dir_conf
statusdir_dir_conf=(

  [index]="/var/local/statusdir"
  [cache]="/var/cache/statusdir"
  [log]="/var/log/statusdir"

  [tree]="/usr/share/statusdir"
)

statusdir_user_conf=(
  [name]=$USER
  [group]=staff
)

# Legacy and new export path
: "${STATUSDIR_ROOT:=$HOME/.local/var/statusdir/}"
: "${METADIR_GLOBAL:=${statusdir_dir_conf["index"]}}"

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

    * ) fail
  esac
}

init ()
{
  [[ -d "${STATUSDIR_ROOT}" ]] || {
    >&2 mkdir -vp "${STATUSDIR_ROOT}" || return
  }
  local sub
  local -n trgt="statusdir_dir_conf[\$sub]"
  for sub in "${!statusdir_dir_conf[@]}"
  do
    [[ -d "${trgt:?Missing mapping value for $sub}" ]] && continue
    >&2 mkdir -vp "$trgt" || return
    sudo chown root:staff "$trgt"
    sudo chmod g+srwx "$trgt"
    [[ -h "${STATUSDIR_ROOT}${sub}" ]] && continue
    >&2 ln -vs "${trgt:?}" "${STATUSDIR_ROOT}${sub}" || return
  done
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

"$@"
