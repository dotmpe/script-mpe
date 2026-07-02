# Copyright: (C) 2025 qwrt <qwrt@t460s>
#
# .group.bash file, see User-Conf us-part for specification.
#
# Distributed under terms of the MIT license.

uc_basedir_pre=User-Conf.Basedir
uc_basedir_cnk=60347cac
uc_basedir_fun=(
  .basedirs_split-argv
  # TODO: .basedir+init
  # TODO: .basedir-command
  .basedirs
  .basedirs+load
)
declare -gA \
uc_basedir_hooks=(
  [init]=$uc_basedir_pre.basedirs+load
)

User-Conf.Basedir.basedirs_split-argv ()
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

User-Conf.Basedir.basedir+init ()
{
  TODO "$FUNCNAME"
}

User-Conf.Basedir.basedir-command ()
{
: param '~ <Dirid> <Command...>'
  TODO "$FUNCNAME, see User.DSL.user-ops-main for now"
}

User-Conf.Basedir.basedirs ()
{
: param '~ [<List-arg...> -- ] <Sub...>'
  local -a _uc_bd_{select,subcmd} _uc_bd_key
  ${FUNCNAME}_split-argv _uc_bd_{select,subcmd} "$@" && {
    [[ ${_uc_bd_select[*]:+set} ]] ||
    _uc_bd_select=( printf '' "${}" )
  } &&
  User-Script.System.read-call _uc_bd_key "${_uc_bd_select[@]}" &&

  for bd_key in "${_uc_bd_key[@]}"
  do
    "${_uc_bd_subcmd[@]}"
  done
}

User-Conf.Basedir.basedirs+load ()
{
  if_ok "${US_BASEDIR_CACHE:=$(command -v basedir,user.data.bash)}" ||
    failerr "Missing User-Script basedir cache filepath setting" || return
  declare -ga uc_basedir_key
  cache_loadmaps "$US_BASEDIR_CACHE" uc_basedir_{,path}id ||
    failerr "E$? loading User-Script basedirs cache" || return

  [[ ${uc_basedir_commands[*]:+set} ]] || {
  # ((${#uc_basedir_commands[*]})) ||  {
    : "${US_BASEDIR_COMMANDS:-init sync update}"
    cache_setlist uc_basedir_commands "( ${_//:/ } )" "$US_BASEDIR_CACHE"
  }
  [[ ${uc_basedir_fields[*]:+set} ]] || {
  # ((${#uc_basedir_fields[*]})) ||  {
    : "${US_BASEDIR_FIELDS:-cfg}"
    cache_setlist uc_basedir_fields "( ${_//:/ } )" "$US_BASEDIR_CACHE"
  }

  # Make sure all user declared commands have basedir maps
  local f &&
  for f in "${uc_basedir_commands[@]}" "${uc_basedir_fields[@]}"
  do
    local -n _ref=user_basedir_${f}
    [[ "${_ref[*]:+set}" ]] || declare -ga user_basedir_${f}
  done

  # XXX: would be nice to have config deal wtih schema, mappings etc. but do
  # envd integration first.
  #uc_config -n \
  #  uc_dirnum '${uc_basedir_pathid["$PWD"]}' \
  #  uc_dirlabel '${uc_basedir_key[$uc_dirnum]}' \
  #  uc_dirtype '${user_basedir_type[$uc_dirnum]}' \
  #  uc_diruuid '${user_basedir_uuid[$uc_dirnum]}'
  declare -gn \
    uc_dirnum='uc_basedir_pathid["$PWD"]' \
    uc_dirlabel='uc_basedir_key[$uc_dirnum]'
  local field
  for field in "${uc_basedir_fields[@]}"
  do
    declare -gn uc_dir$field='user_basedir_'$field'[$uc_dirnum]'
  done
}

# Id: basedir,uc                                 vim:set ft=bash sw=2 sts=2 et:
