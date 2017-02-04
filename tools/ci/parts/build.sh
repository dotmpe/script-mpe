#!/bin/sh

set -e

# Initialize env
. $scriptdir/tools/sh/init.sh
. ./tools/sh/env.sh
. $scriptdir/main.lib.sh

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
        . ./tools/ci/test.sh
      ;;

    dev ) main_debug

        note "Pd version:"
        # FIXME: pd alias
        # TODO: Pd requires user-conf.
        (
          pd version || noop
          projectdir.sh version || noop
          ./projectdir.sh version || noop
        )
        #note "Pd help:"
        # FIXME: "Something wrong with pd/std__help"
        #(
        #  ./projectdir.sh help || noop
        #)
        #./projectdir.sh test bats-specs bats

        # TODO install again? note "gtasks:"
        #./gtasks || noop

        note "Htd script:"
        (
          htd script
        ) && note "ok" || noop

        note "Pd/Make test:"
        #( test -n "$PREFIX" && ( ./configure.sh $PREFIX && ENV=$ENV ./install.sh ) || printf "" ) && make test
        (
          ./configure.sh && make build test
        ) || noop

        note "basename-reg:"
        (
          ./basename-reg ffnnec.py
        ) || noop
        note "mimereg:"
        (
          ./mimereg ffnenc.py
        ) || noop

        note "lst names local:"
        #892.2 https://travis-ci.org/dotmpe/script-mpe/jobs/191996789
        (
          lst names local
        ) || noop
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
