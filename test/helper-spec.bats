#!/usr/bin/env bats

base=test/helper.bash
load helper
init


@test "${lib}/${base} - is_skipped: returns 0 if ENV_SKIP=1 or 1, no output" {

    run is_skipped foo
    test "${status}" = 1
    test "${lines[*]}" = ""

    run bash -c '. '${lib}/${base}' && FOO_SKIP=1 is_skipped foo'
    test "${status}" = 0
    test "${lines[*]}" = "" || fail "Output: ${lines[*]}"

    FOO_SKIP=1
    run is_skipped foo
    test "${status}" = 0
    test "${lines[*]}" = ""
}

@test "${lib}/${base} - current_test_env: echos valid env, returns 0" {

    run current_test_env
    test "${status}" = 0

    test -z "$TEST_ENV" || {
      mkvid "$(hostname -s)"
      diag "${lines[@]} TEST_ENV=$TEST_ENV username=$(whoami) hostid=$vid"
      test "${lines[0]}" = "$vid" \
        || test "${lines[0]}" = "$(whoami)" \
        || test "${lines[0]}" = "$TEST_ENV"
    }
}

@test "${lib}/${base} - check_skipped_envs: returns 0 or 1, no output" {

    run check_skipped_envs foo bar baz
    test "${status}" = 0
    test "${lines[*]}" = "" # No output

    run check_skipped_envs
    test "${status}" = 1
    test "${lines[*]}" = "" # No output

    key=$(get_key "$(hostname -s)")
    keys="${key}_SKIP=1 $(whoami | tr 'a-z' 'A-Z')_SKIP=1"

    run bash -c '. '${lib}/${base}' && '"$keys"' check_skipped_envs'
    test "${status}" = 1 || test -z "Should have failed: default envs is all envs"
    test "${lines[*]}" = ""
}

@test "${lib}/${base} - check_skipped_envs: check current env" {
    run check_skipped_envs
    test "${status}" = 1 || test -z "Should have set {ENV}_SKIP=1 for proper test! do it now. "
}

