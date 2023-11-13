#!/usr/bin/env bash

true "${UB_AC_SH:="$US_BIN/${PROJECT_CACHE:-.meta/cache}/usernew.ac.sh"}"

#test -e "${UB_AC_SH:?}" || {
#  menu.sh shell-autocomplete >| ""
#}

#for menu_name in $(menu.sh user-menus)
#do
#  ! "${UC_DEBUG:-false}" ||
#    $LOG warn :user-new.ac.sh "Adding ..." "menu: $menu_name"
#  if [[ $(type -t compopt) = "builtin" ]]; then
#      complete -o default -F __ub_ac_start "$menu_sid"
#  else
#      complete -o default -o nospace -F __ub_ac_start "$menu_sid"
#  fi
#done
