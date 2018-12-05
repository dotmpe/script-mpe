#!/bin/sh

# Report times for CI script phases

note "Main CI Script run-time: $(echo "$script_end_ts - $script_ts"|bc) seconds"
note "CI run-time since start: $(echo "$report_times_ts - $ci_env_ts"|bc) seconds"

# Travis build-phases and CI/part scripts

note "Reporting CI phase event times:"
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

    deltasec="$(( $(sec_nomicro "$script_ts") - $(sec_nomicro "$ts") ))"

    echo "$event: $(fmtdate_relative "" "$deltasec") ($deltamicro seconds)"

    true
done | column -tc3
