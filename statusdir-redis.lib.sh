#!/bin/sh

set -e


sd_be_name=redis

redis()
{
  case "$1" in

    get )
        v=$(redis-cli get "$2" || return)
        test -n "$v" && eval echo $v || return
      ;;
    set ) redis-cli set "$2" "$4" || return ;;
    incr ) redis-cli INCR "$2" || return ;;
    decr ) redis-cli DECR "$2" || return ;;
    del ) redis-cli DEL "$2" || return ;;
    ping ) redis-cli PING 2>&1 >/dev/null || return ;;

    scan|list )
        test -n "$2" || set -- "$1" 0
        redis-cli scan "$2" || return
      ;;

    exists ) shift ; test 1 -eq $( redis-cli --raw "exists" "$@" ) ;;
    has ) shift ; test 1 -eq $( redis-cli --raw "sismember" "$@" ) ;;
    members ) shift ; redis-cli --raw "smembers" "$@" ;;
    add ) shift ; test 1 -eq $(redis-cli --raw "sadd" "$@" ) ;;
    rem ) shift ; test 1 -eq $(redis-cli --raw "srem" "$@" ) ;;

    publish ) shift ; redis-cli PUBLISH "$1" "$2" || return ;;
    subscribe ) shift ; redis-cli --csv SUBSCRIBE "$1" || return ;;
    psubscribe ) shift ; redis-cli --csv PSUBSCRIBE "$1" || return ;;

    backend ) echo redis ;;

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
