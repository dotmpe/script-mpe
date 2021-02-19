#!/bin/sh

# Memcache client in Bash. See tools.yml.
sd_membash ()
{
  case "$1" in
    ping )
        test -x "$(which membash)" || return
        test -n "$(membash stats)" || return
      ;;
    list )
        membash list_all_keys || return
      ;;
    get )
        v=$(membash "$@" || return)
        test -n "$v" && echo "$v" || return
      ;;
    del|delete) shift ;
        membash delete "$@" || return
      ;;
    stats|get|set|incr|decr )
        membash "$@" || return
      ;;
    backend )
        echo memcache 11211
      ;;
    x|be )
        shift
        membash "$@" || return
      ;;
    * )
        echo "Error $0: $1 ($*)"
        exit 101
      ;;
  esac
}

statusdir_memcache_lib_load ()
{
  Statusdir__backend_types["memcache"]=MemBash
}

class.Statusdir.MemBash ()
{
  test $# -gt 0 || return
  test $# -gt 1 || set -- $1 .default
  local self="class.Statusdir.MemBash $1 " id=$1 m=$2
  shift 2

  case "$m" in

    .default | \
    .info )
        echo "@Statusdir.MemBash <#$id>"
      ;;

    * )
        $LOG error "" "No such endpoint '$m' on" "$($self.info)" 1
      ;;
  esac
}

#
