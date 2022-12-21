
### Run bm-sh-grep cases as suite with bench tool

bm=tools/benchmark/bm-sh-grep.sh
source "$bm"

# Scenario: Grep a 4k script file for not-comment lines (see bm-sh-grep):
#
# GNU Grep               2.6ms
# GNU Grep -E           ~2.7ms
# GNU Grep (unicode)     3.1ms
# Ripgrep               ~5ms

# Ran on an as quietly possible dev laptop with desktop and container services
# turned off, only SSH user login process, i7-7820HQ. Some strange ramping
# in regression graph plots; not sure if due to freq scaling or some heuristic
# artefact.

# Conclusion: unicode (GNU toolkit) has less than an effect from what I
# expected or have seen before. Ripgrep does not perform significantly different
# for ASCII or UTF-8. Had to include sh -c to get env to work with bench, so
# there is some overhead there.


echo "bench \
  ${bench_opt:-} \
  --output test_bm_grep.html \
  $(cat <<EOM
  'sh -c "$(funbody test_1a_grep | sed 's/"/\\"/g')"' \
  'sh -c "$(funbody test_1a2_grep_C | sed 's/"/\\"/g')"' \
  'sh -c "$(funbody test_1b_egrep | sed 's/"/\\"/g')"' \
  'sh -c "$(funbody test_1b2_egrep_C | sed 's/"/\\"/g')"' \
  'sh -c "$(funbody test_2b1_ripgrep_C | sed 's/"/\\"/g')"' \
  'sh -c "$(funbody test_2b2_ripgrep | sed 's/"/\\"/g')"' \
  'sh -c "$(funbody test_2b3_ripgrep | sed 's/"/\\"/g')"'
EOM
)"

export bre re testf
eval "bench \
  ${bench_opt:-} \
  --output test_bm_grep.html \
  $(cat <<EOM
  'sh -c "$(funbody test_1a_grep | sed 's/"/\\"/g')"' \
  'sh -c "$(funbody test_1a2_grep_C | sed 's/"/\\"/g')"' \
  'sh -c "$(funbody test_1b_egrep | sed 's/"/\\"/g')"' \
  'sh -c "$(funbody test_1b2_egrep_C | sed 's/"/\\"/g')"' \
  'sh -c "$(funbody test_2b1_ripgrep_C | sed 's/"/\\"/g')"' \
  'sh -c "$(funbody test_2b2_ripgrep | sed 's/"/\\"/g')"' \
  'sh -c "$(funbody test_2b3_ripgrep | sed 's/"/\\"/g')"'
EOM
)"

#
