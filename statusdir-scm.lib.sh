#!/usr/bin/env bash

statusdir_scm_lib_load ()
{
  Statusdir__backend_types["scm"]=SCM
}

class.Statusdir.SCM () # Instance-Id Message-Name Arguments...
{
  test $# -gt 0 || return
  test $# -gt 1 || set -- $1 .default
  local name=Statusdir.SCM
  local self="class.$name $1 " id=$1 m=$2
  shift 2

  case "$m" in
    .$name ) Statusdir__params[$id]="$*" ;;

    .default | \
    .info )
        echo "class.$name <#$id> ${Statusdir__params[$id]}"
      ;;

    * )
        $LOG error "" "No such endpoint '$m' on" "$($self.info)" 1
      ;;
  esac
}

#
