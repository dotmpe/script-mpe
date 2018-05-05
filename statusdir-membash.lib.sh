#!/bin/sh

set -e

# Memcache client in Bash. See tools.yml.
sd_be_name=membash_f
membash_f()
{
  case "$1" in
    ping )
        test -n "$(membash stats)"
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
        echo "Error $0: $1 ($2)"
        exit 101
      ;;
  esac
}
