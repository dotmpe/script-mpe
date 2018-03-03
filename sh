#!/bin/sh

set -e

export sd_be=redis
export sd_be=membash

statusdir.sh get mykey1 || true
statusdir.sh set mykey1 foo
statusdir.sh get mykey1
statusdir.sh del mykey1
exit $?

export \
sd_be=couchdb_sh \
COUCH_URL="https://hari:vLh,9ujwktNqwfqr5K8dCN@couch.wtwta.org" \
COUCH_DB=test

statusdir.sh backends
exit $?

statusdir.sh get mykey1 || true
statusdir.sh set mykey1 10
statusdir.sh incr mykey1
statusdir.sh incr mykey1
statusdir.sh get mykey1
statusdir.sh incr mykey1
statusdir.sh get mykey1
statusdir.sh decr mykey1
statusdir.sh decr mykey1
statusdir.sh decr mykey1
statusdir.sh get mykey1
statusdir.sh decr mykey1
statusdir.sh get mykey1
echo deleting
statusdir.sh del mykey1
statusdir.sh get mykey1 || true
echo ok
exit $?



test sh-finfo.sqlite ||
  db_sa.py --dbref=sh-finfo.sqlite init

finfo.py --dbref=sh-finfo.sqlite --update .


exit $?

hier.py import tags.list
exit $?

# https://explainshell.com/explain?cmd=rst2html+--record-dependencies%3DFILE

for x in test/*-spec.bats; do
    bats "$x" && {
        echo ""
        continue
    }
    echo "Failed: $? $x"
    echo ""
done

exit $?

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
