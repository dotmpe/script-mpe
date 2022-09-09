#!/usr/bin/env bash

test ${verbosity:=4} -le 5 || {
  wc -l "$passed" "$failed" || true
}

pass_cnt=$(grep -v '^\s*\(#.*\|\s*\)$' "$passed"|wc -l|awk '{print $1}')
fail_cnt=$(grep -v '^\s*\(#.*\|\s*\)$' "$failed"|wc -l|awk '{print $1}')

test $fail_cnt -eq 0 && {

  print_green "OK" "Passed ($pass_cnt)"
  test ${verbosity:=0} -le 5 || tail -n+2 $passed
} || {

  print_yellow "" "Passed ($pass_cnt)";
  test ${verbosity:=0} -le 5 || {
    echo "Passed tests:" >&2
    grep -i 'OK ' $B/reports/*/*.tap >&2
  }
  test ${verbosity:=0} -le 4 || {
    echo "Passed steps ($pass_cnt):" >&2
    tail -n+2 $passed
  }

  print_red "Error" "Failed ($fail_cnt)"
  test ${verbosity:=0} -le 4 || {
    echo "Failed tests:" >&2
    grep -i 'NOT OK ' $B/reports/*/*.tap|grep -v '-negative.bats'>&2
  }
  test ${verbosity:=0} -le 3 || {
    echo "Failed steps ($fail_cnt):" >&2
    tail -n+2 $failed >&2
  }
}

step_cnt=$(( $pass_cnt + $fail_cnt ))
ci_announce "Finished CI session ($pass_cnt/$step_cnt passed/total steps) <$SESSION_ID>"

rm "$passed" "$failed"
unset SESSION_ID
# Sync: U-S:
