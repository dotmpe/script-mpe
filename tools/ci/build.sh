#!/bin/bash

set -e

. ./tools/sh/env.sh
. ./util.sh
. ./main.lib.sh

note "entry-point for CI build phase"


# Start build per env
test -n "$1" || . ./tools/ci/auto-targets.sh

while test -n "$1"
do
  case "$1" in

     production )
        # XXX: work in progress. project has only dev or ENV= builds
        #./configure.sh /usr/local && sudo ENV=$ENV ./install.sh && make test build
        DESCRIBE="$(git describe --tags)"
        grep '^'$DESCRIBE'$' ChangeLog.rst && {
          echo "TODO: get log, tag"
          exit 1
        } || {
          echo "Not a release: missing change-log entry $DESCRIBE: grep $DESCRIBE ChangeLog.rst)"
        }
      ;;

    test* )
        #./configure.sh && make build test
        . ./tools/ci/test.sh
      ;;

    dev )
        main_debug

        #./gtasks

        #./box-instance x foo bar
        #./box-instance y

        #./match.sh help
        #./match.sh -h
        #./match.sh -h help
        #./match.sh -s var-names

        # TODO: cleanup. Pd requires user-conf.
        #./projectdir.sh test bats-specs bats
        #( test -n "$PREFIX" && ( ./configure.sh $PREFIX && ENV=$ENV ./install.sh ) || printf "" ) && make test


        #./matchbox.py help
        #./libcmd_stacked.py -h
        #./radical.py --help
        #./radical.py -vv -h

        ./matchbox.py

        ./basename-reg --help
        #./basename-reg ffnnec.py
        #./mimereg ffnenc.py

        python sh_switch.py
      ;;

    jekyll )
        bundle exec jekyll build
      ;;

    noop )
        note "Empty Build! ($1)" 0
      ;;

    * )
        error "Unknown build '$1'" 1
      ;;

  esac

  note "Build '$1' done"

  shift 1
done
