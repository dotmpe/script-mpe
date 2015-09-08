#!/usr/bin/env bats

base=test/helper.bash
load helper
init_bin

@test "${bin} is_skipped returns 0 if ENV_SKIP=1 or 1, no output" {

    run is_skipped foo
    test "${status}" = 1
    test "${lines[*]}" = ""

    run bash -c '. '${bin}' && FOO_SKIP=1 is_skipped foo'
    test "${status}" = 0
    test "${lines[*]}" = ""

    FOO_SKIP=1
    run is_skipped foo
    test "${status}" = 0
    test "${lines[*]}" = ""
}

@test "${bin} current_test_env echos valid env, returns 0" {

    run current_test_env
    test "${status}" = 0
    test "${lines[0]}" = "$(hostname -s)" || test "${lines[0]}" = "$(whoami)"
}

@test "${bin} check_skipped_envs returns 0 or 1, no output" {

    run check_skipped_envs foo bar baz
    test "${status}" = 0
    test "${lines[*]}" = ""

    key=$(hostname -s | tr 'a-z-' 'A-Z_')
    run bash -c '. '${bin}' && '$key'_SKIP=1 check_skipped_envs '$(hostname -s)' '$(whoami)
    test "${status}" = 1 || test -z "Should have failed"
    test "${lines[*]}" = ""
}

@test "${bin} check_skipped_envs check current env" {
    run check_skipped_envs $(hostname -s) $(whoami)
    test "${status}" = 1 || test -z "Should have set {ENV}_SKIP=1 for proper test"
}
