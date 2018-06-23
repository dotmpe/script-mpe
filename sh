#!/bin/sh
set -e

./txt.py doctree docs.list .
exit $?


#diff build/test/list1.txt build/test/list2.txt
#diff build/test/list1.txt build/test/list3.txt
exit $?


cp test/var/list.txt/list1.txt build/test/list1.txt
{ echo 'Id-5: tralala'; } | list.py update-list build/test/list1.txt
diff build/test/list1.txt build/test/list2.txt
echo ok 1

{ echo '00003: oops'; } | list.py update-list build/test/list1.txt
{ echo '4: oooops II'; } | list.py update-list build/test/list1.txt
diff build/test/list1.txt build/test/list3.txt
echo ok 2

exit $?


diff test/var/list.txt/list1.txt build/test/list1.txt
exit $?

mkdir -vp build/test
cp test/var/list.txt/list1.txt build/test/list1.txt
{ echo 'Id-5:'; } | list.py update-list build/test/list1.txt
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
#vendor/bin/behat --dry-run --no-multiline

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
