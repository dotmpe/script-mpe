#!/bin/sh
set -e


#test -d ~/.pyvenv/htd || virtualenv ~/.pyvenv/htd
#scriptpath=$(pwd) . ./util.sh
#lib_load
#lib_load src table projectenv

#build_redo_changed=1 ./build.sh all

#lib_load build-test &&
#build_test_init &&

#rm .cllct/testruns/*.tap || true

export CS=dark
#./build.sh all_tests_static
#build_coverage ./build.sh all_tests_static

#shells=bash test_shells ./build.sh required_tests

docker pull bvberkum/treebox:dev &&
docker run --rm \
    -w /dut \
    -v $(pwd -P)/tools/ci/docker.sh:/dut/run.sh \
    bvberkum/treebox:dev sh ./run.sh

exit $?

. ./tools/sh/env.sh

test_any_feature "$@"
exit $?

p='' s='' act=$component_tests foreach_do "$@" |
      p='' s='' act=$component_test foreach_do

exit $?

projectdir.sh run :git:status
exit $?

projectdir.sh run :bats:specs
vendor/bin/behat --dry-run --no-multiline

htd status
htd rules
htd run-rules ~/.conf/rules/boreas.tab

exit $?


#foo=123
#testme()
#{
#  test sh -nt build.lib.sh
#}
#exec_watch_poll testme echo "\$foo" -- touch build.lib.sh


#poll_sleep=2
#lib_load vc
#reload()
#{
#  . ./build.lib.sh
#  test_scm
#}
#exec_watch_scm reload


#verbosity=7
exec_watch_scm
exit $?
  
htd tasks --Check-All-Tags --Check-All-Files --update

#redo doc/src/sh/default.dot.gv
exit $?

lib_load build
project_test mod_jsotk jsotk-py jsotk-xml
exit $?

# TODO: create mediameta records, metadata cards with id, format, key, date info etc.
finfo-app.py --name-and-categorize .
exit $?

test sh-finfo.sqlite || db_sa.py --dbref=sh-finfo.sqlite init
finfo.py --dbref=sh-finfo.sqlite --update .
exit $?

hier.py import tags.list
exit $?

# https://explainshell.com/explain?cmd=rst2html+--record-dependencies%3DFILE

exit $?
