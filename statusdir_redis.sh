#!/bin/sh

set -e


redis()
{
  case "$1" in

    get )
        redis-cli get "$1"
      ;;
    set )
        redis-cli set "$1" "$3"
      ;;
    incr )
        redis-cli incr "$1"
      ;;
    del )
        redis-cli del "$1"
      ;;
    ping )
        redis-cli ping 2>&1 >/dev/null
      ;;
    * )
        echo "Error $0: $1 ($2)"
        exit 101
      ;;
  esac
}


