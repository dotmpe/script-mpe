#!/bin/sh

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
      echo "ENV=$ENV"
      pwd

       #( test -n "$PREFIX" && ( ./configure.sh $PREFIX && ENV=$ENV ./install.sh ) || printf "" ) && make test
       #bats
       #./projectdir.sh run bats-specs
      . ./util.sh
      . ./main.sh
      main_debug

      ./esop.sh x

       #match.sh help
       #match.sh -h
       #match.sh -h help
       #- ./basename-reg ffnnec.py
       #- ./mimereg ffnenc.py

     ;;

esac


