#!/bin/ash
test -z "${sh_baseline:-}" ||
    $LOG "error" "" "Baseline recursion?" "${sh_baseline:-}" 1
export sh_baseline=1

announce 'Check project baseline'

: "${baseline_d:="test/baseline/"}"
: "${baselines:="1-shell 2-bash 3-project 4-mainlibs bats realpath git redo"}"
: "${baseline_ext:=".bats"}"
: "${baseline_reset_env:=" CWD= INIT_LOG= scriptpath= SCRIPTPATH= U_S= "}"
for baseline in $baselines
do
  eval $reset_env

  test -e $baseline_d$baseline$baseline_ext || {
    print_yellow "ci:bl:bats-suite" "No baseline $baseline, skipped"
    continue
  }

  print_yellow "ci:bl:bats-suite" "$baseline baseline"
  bats $baseline_d$baseline$baseline_ext &&
    print_green "OK" "$baseline baseline" || print_red "Not OK" "$baseline"

  # TODO: escalate but delay failures to build-result at end of CI suite
done

export sh_baseline=0
