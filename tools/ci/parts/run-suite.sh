  test $# -ge 2 || return 98
  local parts= tab="$1" suite="$2" ; shift 2
  test -n "$tab" || tab=build.txt
  head -n 1 "$tab" | grep -q "\<$suite\>" || return 97

  test $# -gt 0 && for phase in $@
  do
    stage=$suite.$phase
    suite_run "$tab" "$suite" $phase || return

  done ||
    suite_run "$tab" "$suite" $phase

# Sync: U-S: vim:ft=bash:
