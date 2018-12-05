#!/bin/sh

jsotk yaml2json ".travis.yml" > .htd/travis.json
echo '-------------------'

# TODO: Report on host load
uptime
ping -c3 cdnjs.com
ping -c3 traviscistatus.com
# FIXME: may want to get stats of running builds, backlog
# Don't really understant why there are so few container builds
echo '-------------------'
htd package update
echo '-------------------'
echo Path: $SCRIPTPATH
lib_assert os sys str shell build || true

lib_load statusdir
statusdir_init

#build_test_init

lib_load main
lib_load package project-stats build-test
lib_init
echo '-------------------'
expand_spec_src libs
#| p= s= act=count_lines foreach_addcol >>"$@"
echo '-------------------'
set -- "$LIB_LINES_TAB" "$LIB_LINES_COLS"
test ! -e "$1" || {
    project_stats_list_summarize "$@"
    echo '-------------------'
}
htd project-stats build
echo '-------------------'

# FIXME: redo
#std_info "Running all tests..."
#  all_tests_static

#test_any_feature "test/stattab.feature"

jq -r '.cache.directories[]' .htd/travis.json | while read c
do
    eval "du -s $c" || true
done


main_debug

note "Esop:"
(
  export verbosity=7
  esop.sh version || true
  export verbosity=4
  esop.sh version || true
  esop.sh || true
  esop.sh -vv -n help || true
)

#note "Pd help:"
#(
#  ./projectdir.sh help || true
#  ./projectdir.sh --version || true
#  ./projectdir.sh test bats-specs bats || true
#)

note "vagrant-sh"
(
   ./vagrant-sh.sh -h || true
)

# TODO install again? note "gtasks:"
./gtasks || true

# Id: script-mpe/0.0.4-dev tools/sh/build/dev.sh
