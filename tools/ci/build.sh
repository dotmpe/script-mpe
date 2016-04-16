#!/bin/sh

set -e

case "$ENV" in

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

   test* | dev* )
       #./configure.sh && make build test
     ;;

   * )
      env

      # XXX: Skip build on git-annex branches
      test -n "$TRAVIS_COMMIT" || GIT_CHECKOUT=$TRAVIS_COMMIT
      GIT_CHECKOUT=$(git log --pretty=oneline | head -n 1 | cut -f 1 -d ' ')
      BRANCH_NAMES="$(echo $(git ls-remote origin | grep -F $GIT_CHECKOUT \
        | sed 's/.*\/\([^/]*\)$/\1/g' | sort -u ))"
      echo "Branch Names: $BRANCH_NAMES"
      case "$BRANCH_NAMES" in "*annex*" ) exit 0 ;; esac

      echo "TRAVIS_SKIP=$TRAVIS_SKIP"
      echo "ENV=$ENV"
      echo "Build dir: $(pwd)"

      . ./util.sh
      . ./main.sh
      main_debug

      #./box-instance x foo bar
      #./box-instance y

      #./match.sh help
      #./match.sh -h
      #./match.sh -h help
      #./match.sh -s var-names
#
      #bats
      ./projectdir.sh test bats-specs bats
      #( test -n "$PREFIX" && ( ./configure.sh $PREFIX && ENV=$ENV ./install.sh ) || printf "" ) && make test

      #./matchbox.py help
      #./libcmd_stacked.py -h
      #./radical.py --help
      #./radical.py -vv -h

      ./matchbox.py

      ./basename-reg --help
      #./basename-reg ffnnec.py
      #./mimereg ffnenc.py



     ;;

esac


