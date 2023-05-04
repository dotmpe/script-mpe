#!/usr/bin/env bash

sd_ramdir()
{
  # Get temporary dir: XXX move to ramdir
  test -n "$sd_tmp_dir" || sd_tmp_dir=$(setup_tmpd $base)
  test -n "$sd_tmp_dir" -a -d "$sd_tmp_dir" || error "sd_tmp_dir load" 1
  local rtype="${fsd_rtype-"tree"}"
  local p=$sd_tmp_dir/$rtype k="${2-}" tlt="${3-}" v="${4-}"

  case "$1" in
    load )
        # sd_ramdir load
        rsync -au ${STATUSDIR_ROOT} $sd_tmp_dir
        . ${sd_tmp_dir}$STATUSDIR_TYPE/.meta.sh
      ;;
    unload )
        rsync -au --delete $sd_tmp_dir/* ${STATUSDIR_ROOT}
      ;;
    check | \
    init | \
    get | \
    set | \
    incr | \
    decr | \
    del | \
    file | \
    ping | \
    assert ) false ;;
    * )
        echo "Error $0: $1 ($2)"
        exit 101
      ;;
  esac
}

statusdir_ramdir_lib__load ()
{
  Statusdir__backend_types["ramdir"]=RAMDir
}

class.Statusdir.RAMDir () # Instance-Id Message-Name Arguments...
{
  test $# -gt 0 || return
  test $# -gt 1 || set -- $1 .default
  local name=Statusdir.RAMDir
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
