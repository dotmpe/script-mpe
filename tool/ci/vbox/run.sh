#!/bin/sh

set -e

test -n "$ENV" || ENV=./env.sh

. $ENV

test -n "$1" || set -- status
case "$1" in

  * )
      vagrant "$@"
    ;;

esac
