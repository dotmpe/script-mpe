#!/bin/sh

set -e

scriptname=tools/ci/docker
type error >/dev/null 2>&1 || { source ~/bin/util.sh; }
test -n "$1" || error "argument expected" 1

case "$1" in

  tbx | treebox | sandbox | test | sandbox-test )

      PWD="$(pwd -P)"
      docker run \
        -u $(whoami) \
        -ti \
        -v $PWD:/opt/script-mpe \
        dotmpe/sandbox \
        bash -c "echo 'Container started..';cd /opt/script-mpe; ./projectdir.sh test"
      ;;

  * )
      error "No $scriptname subcmd '$1'" 1
      ;;
esac
