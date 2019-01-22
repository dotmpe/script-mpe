#!/bin/sh

# Report times for CI script phases


set +u
lib_load date
set -u


RUNTIME=$(echo "$script_end_ts - $script_ts"|bc)
$LOG "note" "" "Main CI Script run-time: $RUNTIME seconds"

report_times_ts=$(date +%s.%N)
detasec=$(echo "$report_times_ts - $ci_env_ts"|bc)
$LOG "info" "" "CI run-time since start: $detasec seconds"


$LOG "note" "" "Reporting CI phase event times ($TEST_ENV, $ENV_NAME, $SUITE):"
for event in $ci_stages
do
  ts="$(eval echo \$${event}_ts)" || continue
  test -n "$ts" || continue
  deltamicro="$(echo "$ts - $script_ts" | bc )"
#  echo "$event: ($deltamicro sec)"
#  echo "  Start: $($gdate --iso=ns -d @$ts) ($ts)"
#  ts_e="$(eval echo \$${event}_end_ts 2>/dev/null )" &&
#    echo "  End: $($gdate --iso=ns -d @$ts_e) ($ts_e)" || true
  deltasec="$(printf -- %s "$deltamicro"|cut -d'.' -f1)"
  #test -n "$deltasec" && rel="$(fmtdate_relative "" "$deltasec")" || rel=
  #$LOG "note" "$event" "$deltasec" "$deltamicro sec"
  echo $deltamicro $event
done | sort -n

# Sync: U-S:
