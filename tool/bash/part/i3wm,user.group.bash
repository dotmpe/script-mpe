# Copyright: (C) 2025 qwrt <qwrt@t460s>
#
# .group.bash file, see User-Conf us-part for specification.
#
# Distributed under terms of the MIT license.

user_i3wm_pre=User.I3wm
user_i3wm_cnk=8eca66a3
user_i3wm_fun=(
  .start-with-name
)
declare -gA \
user_i3wm_als=(
  [.start-program]='i3-msg exec'

  [win_new]=.start-program
  [win_new_withname]=.start-with-name
)
declare -gA \
user_i3wm_ssc=(
)
declare -gA \
user_i3wm_hooks=(
[i3wm+load]=\
': user-data-file "${uc_x11_user_bash:=/var/local/statusdir/x11,user.data.bash}"
cache_loadmaps "$uc_x11_user_bash" uc_x11_cmd_name_opts'
[init]='
  #alias win_new=User.I3wm.start-program
'
)

User.I3wm.start-with-name ()
{
  : about "set instance which is WM_CLASS' first value (second is class--often capitalized)"

  local -n _usr_i3_cmdnameopt='uc_x11_cmd_name_opts["$cmd"]'
  local cmd=${1%% *} rest
  [[ ${_usr_i3_cmdnameopt:+set} ]] ||
    failerr "X11 name (instance) option unsupported for ${cmd@Q}" || return

  [[ ${#1} -eq ${#cmd} ]] || rest=${1: ${#cmd}+1}
  User.I3wm.start-program "$cmd $_usr_i3_cmdnameopt${rest:+ ${rest}}" "${@:2}"
}


# Id: i3wm,user                                  vim:set ft=bash sw=2 sts=2 et:
