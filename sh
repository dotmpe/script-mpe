#!/bin/sh

set -e


# FIXME: above seems to be skipping
for x in ./*.py
do
  test -x "$x" || continue
  bn="$(basename "$x" .py | tr -sc 'A-Za-z0-9_\n' '_' )"
  
  # Skip ignored
  test "1" = "$(eval echo \"\$x_$bn\")" && continue

  ./$x -h >/dev/null 2>&1 || {
    echo "$x $?"
  }
  test ! -e "./-h" || {
    echo "$x"
    return 1
  }
done


DEBUG=1 bats test/py-spec.bats


bats test/htd-spec.bats


for x in test/*-spec.bats; do bats "$x" && continue ; echo "Failed: $? $x" ; done
exit $?


nok=0 keep_going=
test -z "$DEBUG" || keep_going=1
get_py_files


exit 0

projectdir.sh run :git:status
#projectdir.sh run :bats:specs
#vendor/.bin/behat --dry-run --no-multiline

htd status
htd rules
htd run-rules ~/.conf/rules/boreas.tab

exit $?

#htd filter-functions "run=..*" htd
#htd filter-functions  "grp=htd-meta spc=..*" htd

#echo 1.yaml
#export Inclusive_Filter=0
#export out_fmt=yaml
#htd filter-functions "grp=box-src spc=..*" htd
#echo
#
#echo 1.json:
#export out_fmt=json
#htd filter-functions "grp=box-src spc=..*" htd
#echo
#
#echo 1.csv:
#export out_fmt=csv
#htd filter-functions "grp=box-src spc=..*" htd
#echo
#
export Inclusive_Filter=0

echo 2.yaml:
export out_fmt=yaml
htd filter-functions "grp=tmux" htd

echo 2.src:
export out_fmt=src
htd filter-functions "grp=tmux" htd
#
echo 2.csv:
export out_fmt=csv
htd filter-functions "grp=tmux" htd
#
echo 2.json:
export out_fmt=json
htd filter-functions "grp=tmux" htd
