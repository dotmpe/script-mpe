#!/usr/bin/env bash

#define _pp_EOM cat << 'EOM'\
#1\
EOM
#define _pp_debug \
    : "${DEBUG:=0}"\
    : "${QUIET:=0}"\
    ! ((DEBUG)) || {\
      shopt -s extdebug\
      PS4='\[\033[0m\]${BASH_SOURCE:+\[\033[34m\]$BASH_SOURCE\[\033[36m\]:\[\033[32m\]${LINENO}} \[\033[33m\]+\[\033[0m\] '\
      ((QUIET)) ||\
        >&2 echo "$$$-\$ $0 ${*@Q}"\
    }
#define _pp_about while read -r _about\
    do\
      [[ ${_about} = "#endabout" ]] && break\
      [[ ${_about} ]] && ABOUT_HEAD+=${_about}$'\n'\
    done\
    ABOUT_HEAD=${ABOUT_HEAD:0:-1}\
    : "${SCRIPT_ABOUT_HEAD:=$ABOUT_HEAD}"\
    echo "## ${SCRIPT_ABOUT_HEAD//$'\n'/$'\n'## }"

case "$line" in

( "#about" ) [[ ${us_pp_lang} != bash ]] || _pp_about
  ;;

( "#debug" ) [[ ${us_pp_lang} != bash ]] || _pp_EOM(_pp_debug)
  ;;
esac
