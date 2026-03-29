#!/usr/bin/env bash

statusdir_etcd_lib__init ()
{
  etcdctl_exe=$(command -v etcdctl) ||
    _ failerr "E$? no local etcdctl"
  : "${etcdctl_exe:="docker run -ti --net=host shilpamayanna/etcdctl:test etcdctl"}"
  Statusdir__backend_types["etcd"]=Etcd
}

sd_etcd ()
{
  r=0
  while test $# -gt 0
  do
    local act=$1 ; shift
    $LOG debug "" "Etcd running '$act', rest ($#):" "$*"
    case "$act" in

      del )
          >/dev/null $etcdctl_exe del "$1" || return
          shift 1
        ;;

      get )
          $etcdctl_exe get --print-value-only "$1" || return
          shift 1
        ;;

      set )
          >/dev/null $etcdctl_exe put "$1" "$2" || return
          shift 2
        ;;

      ls )
          $etcdctl_exe get --keys-only --prefix "$1" || return
          shift 1
        ;;

      members )
          $etcdctl_exe member list
        ;;

      ping )
          >/dev/null 2>& $etcdctl_exe endpoint health
        ;;

      * )
          $LOG error "" "Etcd:Error: $act? ($*)"
          exit 101
        ;;

    esac
    test $# -eq 0 || {
      test "${1-}" = "--" && shift || {
        $LOG "error" "" "Left-over arguments" "$*" 1
        return 1
      }
    }
  done

  return $r
}

#
