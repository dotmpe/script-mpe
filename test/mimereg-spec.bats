#!/usr/bin/env bats

base=mimereg

load init
init


@test "$bin ffnenc.py" {
  check_skipped_envs travis || \
    TODO "envs $envs: implement bin (test) for env"
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  check_skipped_envs boreas dandy dandy-dev || \
      TODO "SAWarning: Implicitly combining column nodes.id with column volumes.node_id under attribute 'node_id'.  Please configure one or more a ttributes for these same-named columns explicitly."
  test "${#lines[@]}" = "1"
  test "${lines[0]}" = "ffnenc.py: text/x-python"
}

@test "$bin -q ffnenc.py" {
  check_skipped_envs travis || \
    TODO "envs $envs: implement bin (test) for env"
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  check_skipped_envs boreas dandy dandy-dev || \
      TODO "SAWarning: Implicitly combining column nodes.id with column volumes.node_id under attribute 'node_id'.  Please configure one or more a ttributes for these same-named columns explicitly."
  test "${#lines[@]}" = "1"
  test "${lines[0]}" = "text/x-python"
}

@test "$bin -qE ffnenc.py" {
  
  check_skipped_envs travis || \
    TODO "fix envs $envs: implement bin (test) for env"
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0

  case "$(current_test_env)" in dandy ) test "${lines[0]}" = "py";; esac

  check_skipped_envs boreas dandy dandy-dev || \
      TODO "SAWarning: Implicitly combining column nodes.id with column volumes.node_id under attribute 'node_id'.  Please configure one or more a ttributes for these same-named columns explicitly."

  test "${#lines[@]}" = "1"
  test "${lines[0]}" = "py"
}

