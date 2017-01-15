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

        htd script || noop

        # FIXME: pd alias
        #pd version
        projectdir.sh version || noop
        #./projectdir.sh version || noop

        # FIXME: "Something wrong with pd/std__help"
        #projectdir.sh help

        echo "box-instance"
        ./box-instance x foo bar || noop
        ./box-instance y || noop

        echo "Gtasks"
        ./gtasks || noop


        # TODO: cleanup. Pd requires user-conf.
        #./projectdir.sh test bats-specs bats
        #( test -n "$PREFIX" && ( ./configure.sh $PREFIX && ENV=$ENV ./install.sh ) || printf "" ) && make test

        #./basename-reg ffnnec.py
        #./mimereg ffnenc.py

        echo "lst names local"
        #892.2 https://travis-ci.org/dotmpe/script-mpe/jobs/191996789
        lst names local || noop
        # [lst.bash:names] Warning: No 'watch' backend
        # [lst.bash:names] Resolved ignores to '.bzrignore etc:droppable.globs
        # etc:purgeable.globs .gitignore .git/info/exclude'
        #/home/travis/bin/lst: 1: exec: 10: not found
      ;;

    jekyll )
        bundle exec jekyll build
      ;;

    noop )
        # TODO: make sure nothing, or as little as possible has been installed
        note "Empty Build! ($1)" 0
      ;;

    * )
        error "Unknown build '$1'" 1
      ;;

  esac

  note "Build '$1' done"

  shift 1
done
