#!/bin/sh

set -e


sd_be_name=redis

redis()
{
  case "$1" in

    get )
        redis-cli get "$2" || return
      ;;
    set )
        redis-cli set "$2" "$4" || return
      ;;
    incr )
        redis-cli incr "$2" || return
      ;;
    del )
        redis-cli del "$2" || return
      ;;
    ping )
        redis-cli ping 2>&1 >/dev/null || return
      ;;
    list )
        test -n "$2" || set -- "$1" 0
        redis-cli scan "$2" || return
      ;;
    x|be|raw )
        shift 1
        redis-cli --raw "$@" || return
      ;;
    * )
        echo "Error $0: $1 ($2)"
        exit 101
      ;;
  esac
}


statusdir_redis_lib_load()
{
  redis ping || error "no redis server" 1
}

