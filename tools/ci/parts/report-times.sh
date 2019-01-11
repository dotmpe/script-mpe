#!/bin/sh

# Report times for CI script phases


set +u
lib_load date
set -u


deltasec=$(echo "$script_end_ts - $script_ts"|bc)
$LOG "info" "" "Main CI Script run-time: $deltasec seconds"

report_times_ts=$(date +%s.%N)
detasec=$(echo "$report_times_ts - $ci_env_ts"|bc)
$LOG "info" "" "CI run-time since start: $detasec seconds"


$LOG "note" "" "Reporting CI phase event times (test):"
for event in $ci_stages
do
  ts="$(eval echo \$${event}_ts)" || continue
  test -n "$ts" || continue
  deltamicro="$(echo "$script_ts - $ts" | bc )"
#  echo "$event: ($deltamicro sec)"
#  echo "  Start: $($gdate --iso=ns -d @$ts) ($ts)"
#  ts_e="$(eval echo \$${event}_end_ts 2>/dev/null )" &&
#    echo "  End: $($gdate --iso=ns -d @$ts_e) ($ts_e)" || true
  deltasec="$(printf -- %s "$deltamicro"|cut -d'.' -f1)"
  #test -n "$deltasec" && rel="$(fmtdate_relative "" "$deltasec")" || rel=
  $LOG "note" "$event" "$deltasec" "$deltamicro sec"
done


# Travis build-phases and CI/part scripts

$LOG "note" "" "Reporting CI phase event times:"
for event in \
    travis_ci_timer \
    before_install \
        ci_env_1 sh_env_1 sh_env_1_end \
        ci_init \
        ci_announce \
    install \
        ci_env_2 sh_env_2 sh_env_2_end \
        ci_install_end \
    before \
        ci_check \
    script \
        ci_build \
        ci_build_end \
        script_end \
    after_failure \
    after_success \
    after \
        ci_after \
    before_cache \
        ci_before_cache ; do

    ts=$(eval "echo \$${event}_ts") || continue
    test -n "$ts" || continue

    # Report event time relative to script-start
    deltamicro="$(echo "$script_ts - $ts" | bc )"

    deltasec="$(echo "$(sec_nomicro "$script_ts") - $(sec_nomicro "$ts")" | bc )"

    echo "$event: $(fmtdate_relative "" "$deltasec") ($deltamicro sec)"

    true
done | column -tc3
