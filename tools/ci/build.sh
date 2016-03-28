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

      . ./util.sh
      . ./main.sh
      main_debug

      ./esop.sh x

      ./match.sh help
      ./match.sh -h
      ./match.sh -h help
#
      #( test -n "$PREFIX" && ( ./configure.sh $PREFIX && ENV=$ENV ./install.sh ) || printf "" ) && make test
      #bats

      #./matchbox.py help
      #./libcmd_stacked.py -h
      #./radical.py --help
      #./radical.py -vv -h

      ./matchbox.py

      ./basename-reg --help
      #./basename-reg ffnnec.py
      #./mimereg ffnenc.py


      #./projectdir.sh test bats-specs bats || exit $?
      ./projectdir.sh test bats-specs bats



     ;;

esac


