#!/usr/bin/env bash

### Globlist: Lookup and concatenate lists of glob expressions


globlist_lib__load()
{
  lib_require os date-htd meta || return
  #os:if_ok
	#os:remove_dupes_nix
  #os:filter_lines
  #os:read_nix_style_file
	#date-htd:newer_than_all

  : "${CONFIG_GROUPS:="local global"}"
}

globlist_lib__init()
{
  test -z "${globlist_lib_init:-}" || return $_
  ! "${globlist_static_init:-false}" && return
  # This will set the globlist{s,_groups} data and global IGNORES, <base>_IGNORE
  # variables. Using parameterized contexts with class.GlobList allows for more
  # flexible usage, but this lib works without. XXX: Because the script is setup
  # like that anyway, the global at_GlobList could be used to configure another
  # static context as well, should that be useful somehow...
  local ctx=${at_GlobList:-globlist}
  ${ctx}_stddef # && ${ctx}_init
}


globlist_base ()
{
  local ctx=${at_GlobList:-globlist}
  echo "$(${ctx}_prefix)$(${ctx}_basename)"
}

globlist_basename ()
{
  echo "${globlist_basename:-globlist}"
}

globlist_cache ()
{
  local ctx=${at_GlobList:-globlist}
  test 0 -eq $# && {
    if_ok "$(${ctx}_maingroups)" &&
    globlist_refresh $_ &&
    cachef="$(${ctx}_cachefile)" &&
    mainf="$(${ctx}_mainfile)" &&
    cp "$cachef" "$mainf" || return
  } || {
    globlist_refresh $* || return
  }
}

globlist_cachedir ()
{
  echo "${CACHE_DIR:-${METADIR:?}/cache}"
}

# Show path to cache file for given group set, its assumed inputs are ordered
# ie. a different location will be given for every permution.
globlist_cachefile () # ~ [<Groups...>]
{
  local groups suf ctx=${at_GlobList:-globlist}
  groups=${*:-$(${ctx}_maingroups)} || return
  suf=-${groups// /,}
  if_ok "$(${ctx}_use_cachedir)" || return
  "$_" && {
    cachedir=$(${ctx}_cachedir) &&
    base=$(${ctx}_base) &&
    ext=$(${ctx}_ext) || return
    echo "$cachedir/$base$suf$ext"
  } || {
    fn=$(${ctx}_mainfile) || return
    echo "$fn-cache$suf"
  }
}

globlist_ext ()
{
  echo "${globlist_ext:-.${globlist_basename:-globlist}}"
}

globlist_find_files () # ~ <Include-groups>
{
  TODO see ignores_find_files
}

globlist_globlistkey ()
{
  echo "${globlist_globlistkey:-globlists}"
}

globlist_groupkey ()
{
  echo "${globlist_groupkey:-globlist_groups}"
}

globlist_init () # ~ <Base> [<Var-key>]
{
  local base=${1:-${globlist_prefix:?}} varkey=${2:-${1^^}} basename ctx
  ctx=${at_GlobList:-globlist}
  #base="$(${ctx}_base)" &&
  basename="$(${ctx}_basename)" || return
  : "${varkey/#[^A-Z_]/_}"
  local varname=${_//[^A-Z0-9_]/_}_IGNORE fname=.${base:?}$basename
  : "${!varname:-}"
  test -n "$_" && return
  declare -g ${varname?}=$fname
  test -n "${IGNORE_GLOBFILE-}" || {
      IGNORE_GLOBFILE=$fname
      IGNORE_GLOBFILE_BASE=$1
      export IGNORE_GLOBFILE{,_BASE}
    }
  export ${varname?}
}

globlist_lookup () # ~ <Basename>
{
  local conf_dir basepath ext basename=${1:?} ctx=${at_GlobList:-globlist}
  basepath=$(${ctx}_base) &&
  ext=$(${ctx}_ext) || return
  for conf_dir in ${CONFIG_INCLUDE//:/ }
  do
    echo "$conf_dir/$basepath/$basename$ext"
  done
}

globlist_mainfile ()
{
  local ctx=${at_GlobList:-globlist}
  echo ".$(${ctx}_base)"
}

globlist_maingroups ()
{
  echo ${CONFIG_GROUPS:?}
}

globlist_paths () # ~ <Group-names...>
{
  local globlist filelist ctx=${at_GlobList:-globlist}
  filelist=$(${ctx}_pathspecs "$@") || return
  for globlist in $filelist
  do
    case "$globlist" in
      ( etc:* ) ${ctx}_lookup "${globlist#etc:}" ;;
      ( * ) echo "$globlist" ;;
    esac
  done
}

globlist_pathspecs () # ~ [<Group-names...>]
{
  local groupkey globlistkey ctx=${at_GlobList:-globlist}
  { test 0 -lt $# || set -- $(${ctx}_maingroups); } &&
  groupkey="$(${ctx}_groupkey)" &&
  globlistkey="$(${ctx}_globlistkey)" &&
  sh_arr ${groupkey:?} &&
  sh_arr ${globlistkey:?} || return
  while test 0 -lt $#
  do
    # Retrieve value for key either from groups array or from globlist array
    : "${groupkey}[$1]"
    test -n "${!_:-}" && {
      "${globlist_resolve:-true}" "$_" || echo "$_" # echo "$1" "$_"
      set -- $_ "${@:2}"
    } || {
      : "${globlistkey}[$1]"
      test -n "${!_:-}" && {
        ! "${globlist_resolve:-true}" "$_" || echo "$_"
      } || {
        $LOG error :globlist-pathspecs "No such group or file" "$1" ${_E_NF?} ||
          return
      }
      shift
    }
  done
}

globlist_prefix ()
{
  echo ${globlist_prefix:-${base:-}}
}

globlist_raw ()
{
  local globlist filelist ctx=${at_GlobList:-globlist}
  filelist=$(${ctx}_paths "$@") || return
  for globlist in $filelist
  do
    test -s "$globlist" || continue
    echo "# Source: $globlist"
    read_nix_style_file "$globlist" || return
    echo "# EOF"
  done
}

globlist_refresh () # ~ <Group-names...>
{
  local cachef sources
  cachef=$(globlist_cachefile "$@") || return
  if_ok "$(globlist_paths "$@" | filter_lines test -f)" || return
  readarray -t sources <<< "$_"
  test -e "$cachef" &&
  newer_than_all "$cachef" "${sources[@]}" &&
  $LOG debug :globlist-cache "Cache is up-to-date" "$cachef" || {
    globlist_raw "$@" | remove_dupes_nix >| "$cachef" &&
    $LOG info :globlist-cache "Updated" "$cachef" ||
      $LOG warn :globlist-cache "Error updating" "E$?:$cachef" $?
  }
}

globlist_stddef ()
{
  local groupkey globlistkey ctx=${at_GlobList:-globlist} globlistbase

  groupkey="$(${ctx}_groupkey)" &&
  globlistkey="$(${ctx}_globlistkey)" &&
  declare -gA "$groupkey" &&
  declare -gA "$globlistkey" || return
  #basename="$(${ctx}_basename)" &&
  globlistbase="$(${ctx}_base)" || return

  globlist_groups[ignore]=$(echo {local,global}-ignore)
  globlist_groups[global]=global-ignore
  globlist_groups[local]="local-$globlistbase local-ignore"
  globlists[global-ignore]=etc:ignore
  globlists[local-$globlistbase]=.$globlistbase-ignores
  globlists[local-ignore]=.ignore
}

globlist_ttl ()
{
  echo ${globlist_ttl:-${_6HOUR:-21600}}
}

globlist_use_cachedir ()
{
  echo ${globlist_use_cachedir:-true}
}

#
