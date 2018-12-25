#!/bin/ash
# Part of ci:script

# Check project tooling and host env, 3rd party deps

test -z "${sh_baseline:-}" ||
    $LOG "error" "" "Baseline recursion?" "${sh_baseline:-}" 1
export sh_baseline=1


. "./.git/hooks/pre-commit" || print_red "ci:script" "git:hook:ERR:$?"


#print_yellow "" "Starting Tasks baseline..."
#bats test/tasks-spec.bats -f baseline &&
#  print_green "tasks baseline" "OK"||
#    print_red "tasks baseline" "Not OK"

# XXX: cleanup bats test/tasks-lib.bats @Htd


export sh_baseline=0
#
