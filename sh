
set -e


scrow regex --rx-multiline --fmt xtl \
            "htd.sh" '^htd__rule_target\(\).*((?<!\n\})\n.*)*\n\}'

{ cat <<EOM
/Users/berend/bin/htd.sh?scrow=1.0&locspec=charspan:110025/592
/Users/berend/bin/htd.sh?scrow=1.0&locspec=charspan:114073/502
EOM
} | scrow cstream ~/bin/htd.sh --input -

exit 0

/Volumes/ram-tmpdir/htd/9ED6099D-38E2-4643-AB4F-3007BBFF40F5.xml


pd status

pd rules
pd run-rules ~/.conf/rules/boreas.tab

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

echo prefixes.json
htd list-prefixes



magnet.py \
  "http://www.labirintoermetico.com/06Numerologia_Cabala/Crowley_%20Liber_777.pdf" \
  ~/htdocs/Research/Esoteric/Crowley/Liber-777.magma \
  --dn=Aleister_Crowley-Liber_777.pdf \
  --mt=~/htdocs/Research/Esoteric/Crowley/Liber-777.list \
  --mt=~/htdocs/Research/Esoteric/Crowley/Liber-777.rst \
  --init-be

magnet.py \
  "http://www.labirintoermetico.com/06Numerologia_Cabala/Crowley_%20Liber_777.pdf" \
  ~/htdocs/personal/journal/today.rst

exit $?

test -e "Crowley_ Liber_777.pdf" || wget "http://www.labirintoermetico.com/06Numerologia_Cabala/Crowley_%20Liber_777.pdf"

md5sum "Crowley_ Liber_777.pdf"
sha1sum "Crowley_ Liber_777.pdf"

magnet.py "Crowley_ Liber_777.pdf"

ls -la "Crowley_ Liber_777.pdf"

