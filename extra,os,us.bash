us_os_extra_pre=User-Script.OS
us_os_extra_fun=(
  .lookup-list
)
#declare -gA \
#us_os_extra_ssc=(
#)
declare -gA \
us_os_extra_als=(
  [mkdirs]='>&2 mkdir -vp'
  ["PATH+names"]='.lookup-expand PATH'
  ["PATH+lines"]='.lookup-list PATH'
  ["PATH+pathnames"]='.lookup-expand-paths PATH'
  [lookup-tree]='.lookup-expand-pathtree'
  [path-tree]='.lookup-expand-pathtree PATH'
  [path-list]=PATH+lines
  [path-commands]='.lookup-expand-commands PATH'
  ["SCRIPTPATH+names"]='.lookup-expand SCRIPTPATH'
  ["SCRIPTPATH+lines"]='.lookup-list SCRIPTPATH'
  ["SCRIPTPATH+pathnames"]='.lookup-expand-paths SCRIPTPATH'
)

User-Script.OS.lookup-expand ()
{
  User-Script.OS.lookup-expand-safenames "$1" "$2"
}

User-Script.OS.lookup-expand-commands ()
{
  local -a _find_cmds=( -maxdepth 1 -not -type d -executable -printf '%P\n' )
  User-Script.OS.lookup-expand-safenames "$1" "$2" _find_cmds
}

User-Script.OS.lookup-expand-pathtree ()
{
  local -a _find_pathtree=( -type d -not -path '*/.*' )
  User-Script.OS.lookup-expand-safenames "$1" "$2" _find_pathtree
}

User-Script.OS.lookup-expand-paths ()
{
  local -a _find_paths=( -maxdepth 1 -not -type d )
  User-Script.OS.lookup-expand-safenames "$1" "$2" _find_paths
}

User-Script.OS.lookup-expand-safe ()
{
  TODO "Read to arrays for safe handling of anything"
}

User-Script.OS.lookup-expand-safenames ()
{
  : param ' ~ <Lookup-path-var> [<Output-var>] [<Find-filter-argv-var>]'
  : about 'List names found through lookup'
  : XXX "This should be whitespace safe, but is still meant for safe filenames"
  local _bd _print=0
  local -n _lookup=${1:?$FUNCNAME: Name expected for input variable, $ENV_CTX}
  [[ ! ${2:+set} ]] && _print=1 ||
    local -n _dest=${2:?$FUNCNAME:$1: Name expected for output variable, $ENV_CTX}
  [[ ! ${3:+set} ]] &&
    local -a _find_filter=( -maxdepth 1 -not -type d -printf '%P\n' ) ||
    local -n _find_filter=${3:?}
  local -a _arr
  mapfile -t _arr <<< "${_lookup//:/$'\n'}" &&
  [[ ${_arr[@]:+set} ]] &&
  for _bd in "${_arr[@]}"
  do
    if_ok "$(find "$_bd" "${_find_filter[@]}")" &&
    test -n "$_" || continue
    ((_print)) && echo "$_" || _dest=${_dest:+$_dest$'\n'}${_}
  done
}

User-Script.OS.lookup-list ()
{
  local -n _lookup=${1:?}
  local liststr="${_lookup//:/$'\n'}"
  (($#-1)) && {
    User-Script.Shell.byname-set-value "${2}" "$liststr" || return
  }
  echo "$liststr"
}

#
