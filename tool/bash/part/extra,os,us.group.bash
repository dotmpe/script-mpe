# Copyright: (C) 2025 qwrt <qwrt@t460s>
#
# Distributed under terms of the MIT license.

us_os_extra_pre=User-Script.OS.x
us_os_extra_grp=(
)
us_os_extra_var=(
)
us_os_extra_fun=(
  .iter-sources
  .lookup-list
)
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
declare -gA \
us_os_extra_ssc=(
)
declare -gA \
us_os_extra_hooks=(
#  [init]=\
#''
)

User-Script.OS.x.iter-sources ()
{
  : about 'Helper to iterate over specific parts'
  : extended 'This is mostly to explore usage of data, see also iter-parts'
  # This combines iterator and iteratee's in one select, but thats besides the
  # point here.

  local -I US_SCR_{PATH,HASH,EXT}
  : "${US_SCR_PATH:=$SCRIPTPATH}"
  : "${US_SCR_HASH:=_os_script_path}"
  : "${US_SCR_EXT:=.group.bash .bash}"

  case ${1:?} in

  ( --call )
      (($#-1)) || return ${_E_MA:?}
      "${@:2}"
    ;;

  ( --from-map )
      (($#-2)) || return ${_E_MA:?}
      : input "${2?$FUNCNAME${*:+ $*}: Part hash}"
      local -n _32591e26_map1=${2}
      case "${3}" in
      ( --all )
          local -a matches
          ! ((${#_32591e26_map1[@]})) || matches=( "${!_32591e26_map1[@]}" )
          User-Script.OS.x.iter-sources "${@:4}"
        ;;

      ( --keys )
          User-Script.OS.x.iter-sources "${@:1:2}" --all --matches "${@:4}"
        ;;

      ( --match )
          (($#-3)) || return ${_E_MA:?}
          local -a matches
          local key km offset=0
          for km in "${@:4}"
          do
            ((offset+=1))
            [[ ${km:0:1} != - ]] || break
          done
          for key in "${!_32591e26_map1[@]}"
          do
            for km in "${@:4:offset}"
            do
              User-Script.String.globmatch "${km}" "${key}" || continue
              matches+=( "$key" )
            done
          done
          User-Script.OS.x.iter-sources "${@:3+offset}"
        ;;

        * ) return ${_E_nsk:-67}
      esac
    ;;

  ( --loaded )
      (($#-1)) || return ${_E_MA:?}
      User-Script.OS.x.iter-sources --from-map "$US_SCR_HASH" "${@:2}"
    ;;

  ( --matches )
      ! ((${#matches[@]})) || printf '%s\n' "${matches[@]}"
    ;;

  ( --on-path )
      (($#-1)) || return ${_E_MA:?}
      case "${2}" in
      ( --all )
          # XXX: see FIXME, should reset US_SCR_EXT to sensible value here
          User-Script.OS.x.iter-sources --on-path --match '*' "${@:3}"
        ;;

      ( --match )
          (($#-2)) || return ${_E_MA:?}
          local -a bases paths matches
          mapfile -t bases <<< "${US_SCR_PATH//:/$'\n'}"
          local base ext pm script offset=0
          for pm in "${@:3}"
          do
            ((offset+=1))
            [[ ${pm:0:1} != - ]] || break
          done
          for base in "${bases[@]}"
          do
            for pm in "${@:3:offset}"
            do
              # FIXME: nested looping this way (using glob) necissarily yields
              # all extensions, even if they overlap (ie. produce duplicate
              # matches)
              for ext in ${US_SCR_EXT//[: ]/$'\n'}
              do
                for script in "${base}"/${pm}${ext}
                do
                  scriptname=${script:${#base}+1}
                  User-Script.String.globmatch "${pm}" "${scriptname}" || continue
                  matches+=( "$scriptname" )
                  paths+=( "$script" )
                done
              done
            done
          done
          User-Script.OS.x.iter-sources "${@:2+offset}"
        ;;

        * ) return ${_E_nsk:-67}
      esac
    ;;

  ( --paths )
      ! ((${#paths[@]})) || printf '%s\n' "${paths[@]}"
    ;;

    * ) return ${_E_nsk:-67}
  esac
}

User-Script.OS.x.lookup-expand ()
{
  User-Script.OS.x.lookup-expand-safenames "$1" "$2"
}

User-Script.OS.x.lookup-expand-commands ()
{
  local -a _find_cmds=( -maxdepth 1 -not -type d -executable -printf '%P\n' )
  User-Script.OS.x.lookup-expand-safenames "$1" "$2" _find_cmds
}

User-Script.OS.x.lookup-expand-pathtree ()
{
  local -a _find_pathtree=( -type d -not -path '*/.*' )
  User-Script.OS.x.lookup-expand-safenames "$1" "$2" _find_pathtree
}

User-Script.OS.x.lookup-expand-paths ()
{
  local -a _find_paths=( -maxdepth 1 -not -type d )
  User-Script.OS.x.lookup-expand-safenames "$1" "$2" _find_paths
}

User-Script.OS.x.lookup-expand-safe ()
{
  TODO "Read to arrays for safe handling of anything"
}

User-Script.OS.x.lookup-expand-safenames ()
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

User-Script.OS.x.lookup-list ()
{
  local -n _lookup=${1:?}
  local liststr="${_lookup//:/$'\n'}"
  (($#-1)) && {
    User-Script.Shell.byname-set-value "${2}" "$liststr" || return
  }
  echo "$liststr"
}

# Id: extra,os,us                                vim:set ft=bash sw=2 sts=2 et:
