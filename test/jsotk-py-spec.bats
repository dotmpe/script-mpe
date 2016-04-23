#!/usr/bin/env bats

load helper
base=jsotk.py

init_lib
init_bin


@test "${bin} -h" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
}

@test "${bin} from-kv foo=bar" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test "${lines[0]}" = '{"foo": "bar"}'
}

@test "${bin} from-kv foo[]=bar foo[]=123" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test "${lines[0]}" = '{"foo": ["bar", 123]}'
}

@test "${bin} from-kv a/b/c=1 a/d[]=2 a/d[]=3" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test "${lines[0]}" = '{"a": {"b": {"c": 1}, "d": [2, 3]}}'
}



