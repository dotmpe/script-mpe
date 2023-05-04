#!/usr/bin/env bash

statusdir_etcd_lib__init ()
{
  etcdctl="docker run -ti --net=host shilpamayanna/etcdctl:test etcdctl"
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

      get )
          $etcdctl get "$1" || return
          shift 1
        ;;

      set )
          $etcdctl set "$2" "$3" || return
          shift 2
        ;;

      setdir )
          $etcdctl setdir "$2" "$3" || return
          shift 2
        ;;

      ls )
          $etcdctl ls "$1" || return
          shift 1
        ;;

      mkdir )
          $etcdctl mkdir "$1" || return
          shift 1
        ;;

      mk )
          $etcdctl mk "$1" || return
          shift 1
        ;;

      rmdir )
          $etcdctl rmdir "$1" || return
          shift 1
        ;;

      rm )
          $etcdctl rm "$1" || return
          shift 1
        ;;

      members )
          $etcdctl member list
        ;;

      ping )
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
