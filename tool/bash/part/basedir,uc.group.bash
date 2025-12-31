# Copyright: (C) 2025 qwrt <qwrt@t460s>
#
# .group.bash file, see User-Conf us-part for specification.
#
# Distributed under terms of the MIT license.

uc_basedir_pre=User-Conf.Basedir
uc_basedir_cnk=60347cac
uc_basedir_var=(
)
uc_basedir_fun=(
  .basedirs_split-argv
  .basedirs
  .basedir-command
)
declare -gA \
uc_basedir_als=(
)
declare -gA \
uc_basedir_ssc=(
)
declare -gA \
uc_basedir_hooks=(
#  [init]=\
#''
)

User-Config.Basedir.basedirs_split-argv ()
{
  local -n  _uc_bdargv_select=${1} _uc_bdargv_subcmd=${2}
  local _uc_bdargv_o
  local -a _uc_bdargv_tmp
  User-Script.Array.argv-firstseq _uc_bdargv_tmp "${@:3}" && {
    _uc_bdargv_subcmd=( "${_uc_bdargv_tmp[@]}" )
  } || {
    test ${_E_continue:?} -eq $? || return $_

    _uc_bdargv_select=( "${_uc_bdargv_tmp[@]}" )
    _uc_bdargv_o=$(( 1 + ${#_uc_bdargv_tmp[@]} ))
    _uc_bdargv_subcmd=( "${@:_uc_bdargv_o}" )
  }
  [[ ${_uc_bdargv_subcmd[*]:+set} ]] ||
    failerr "Expected command to run" || return

  [[ ${_uc_bdargv_subcmd[0]:0:1} != . ]] ||
    _uc_bdargv_subcmd[0]="$uc_basedir_pre${_uc_bdargv_subcmd[0]:1}"

  [[ ! ${_uc_bdargv_select[*]:+set} ]] || {
    [[ ${_uc_bdargv_select[0]:0:1} != . ]] ||
      _uc_bdargv_select[0]="$uc_basedir_pre${_uc_bdargv_select[0]:1}"
  }
}

User-Config.Basedir.basedirs ()
{
: param '~ [<List-arg...> -- ] <Sub...>'
  local -a _uc_bd_{select,subcmd} uc_basedir_key
  ${FUNCNAME}_split-argv _uc_bd_{select,subcmd} "$@" && {
    [[ ${_uc_bd_select[*]:+set} ]] ||
    _uc_bd_select=( printf '' "${}" )
  } &&
  User-Script.System.read-call uc_basedir_key "${_uc_bd_select[@]}" &&

  for bd_key in "${uc_basedir_key[@]}"
  do
    :
    "${_uc_bd_subcmd[@]}"
  done
}

User-Config.Basedir.basedir+init ()
{
  :
}

User-Config.Basedir.basedirs+load ()
{
  #local -I PATH
  #PATH=$PATH:$SCRIPTPATH
  : "${uc_basedir_bash:=/var/local/statusdir/basedir,user.data.bash}" &&
  cache_loadmaps "$uc_basedir_bash" uc_basedir_{,path}id user_basedir &&
  local f &&
  for f in uc_basedir_{key,paths,commands} "${uc_basedir_commands[@]}"
  do
    local -n _ref=${f}
    [[ "${_ref[*]:+set}" ]] || declare -ga ${f}
  done
}

User-Config.Basedir.basedir-command ()
{
: param '~ <Dirid> <Command...>'
}

# Id: basedir,uc         vim:set ft=bash sw=2 sts=2 et:
