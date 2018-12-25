#!/bin/sh

# Report times for CI script phases

$LOG "info" "" "Main CI Script run-time: $(echo "$script_end_ts - $script_ts"|bc) seconds"
$LOG "info" "" "CI run-time since start: $(echo "$report_times_ts - $ci_env_ts"|bc) seconds"


$LOG "note" "" "Reporting CI phase event times (test):"
for evt in $ci_stages
do
  echo "$evt:"
  ts="$(eval echo \$${evt}_ts)"
  ts_e="$(eval echo \$${evt}_end_ts)"
  echo "  Start: $($gdate --iso=ns -d @$ts) ($ts)"
  echo "  End: $($gdate --iso=ns -d @$ts_e) ($ts_e)"
  true
done


lib_load date


# Travis build-phases and CI/part scripts

$LOG "note" "" "Reporting CI phase event times:"
for event in \
    travis_ci_timer \
    before_install \
        ci_init \
        ci_env sh_env sh_env_end \
        ci_announce \
    install \
        ci_install_end \
    before_script \
        ci_check \
    script \
        ci_build \
        ci_build_end \
        script_end \
    after_failure \
    after_success \
    after_script \
        ci_after \
    before_cache \
        ci_before_cache ; do

    ts=$(eval "echo \$${event}_ts") || continue
    test -n "$ts" || continue

    # Report event time relative to script-start
    deltamicro="$(echo "$script_ts - $ts" | bc )"

    deltasec="$(echo "$(sec_nomicro "$script_ts") - $(sec_nomicro "$ts")" | bc )"

    echo "$event: $(fmtdate_relative "" "$deltasec") ($deltamicro seconds)"

    true
done | column -tc3
