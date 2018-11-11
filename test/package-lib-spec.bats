#!/usr/bin/env bats

load init
base=package.lib
init
load assert
lib_load package sys


setup()
{
  export package_id=
}


@test "$base: lib-load sets env" {

  assert_equal "./package.yaml" "$PACKMETA"
  #assert_equal "py" "$out_fmt" 
}


@test "$base: lib-set-local sets env" {

  package_lib_set_local "."

  assert_equal "package" "$PACKMETA_BN"
  assert_equal "./.htd/package.main.json" "$PACKMETA_JS_MAIN"
  assert_equal "./.htd/package.sh" "$PACKMETA_SH"
  assert_equal "script-mpe" "$package_id"
}


@test "$base: package-sh" {
  cd /tmp

  PACKMETA_BN="$(package_basename)"
  PACKMETA_SH=./.$PACKMETA_BN.sh

  echo "package_id=foo" > .package.sh
  run package_sh id
  test_ok_nonempty "id=foo" || stdfail 1

  echo "package_id=\"foo bar\" " > .package.sh
  run package_sh id
  test_ok_nonempty "id=\"foo bar\"" || stdfail 2.1

  echo "package_id=foo\ bar" > .package.sh
  run package_sh id
  test_ok_nonempty "id=\"foo bar\"" || stdfail 2.2

  echo "package_id='foo bar'" > .package.sh
  run package_sh id
  test_ok_nonempty "id=\"foo bar\"" || stdfail 2.3
}


@test "$base: package test/var dirs" {

  cd test/var/package/0
  package_lib_load
  package_lib_set_local .
  run package_sh id
  test_ok_nonempty "*id=script-bvb-test-0" || stdfail 1
}


@test "$base: package test/var/package/1 - main and secondary project" {

  cd test/var/package/1

  package_lib_load
  package_lib_set_local .

  run package_sh id key
  test_ok_nonempty "*id=script-bvb-test-1-a key=foo" || stdfail 2

  export package_id=script-bvb-test-1-b
  package_lib_set_local .
  run package_sh id key
  test_ok_nonempty "*id=script-bvb-test-1-b key=bar" || stdfail 3

  # XXX: also allows non-typed entries but don't rely on this?
  export package_id=other
  package_lib_set_local .
  run package_sh id key
  test_ok_nonempty "*id=other key=baz" || stdfail 4
}

@test "$base: package_sh_list" {

  . test/var/package-1-tpl.sh
  echo "$package_1_tpl__1__contents" > /tmp/package.sh

  run package_sh_list "/tmp/package.sh" list_1 "" test_
  test_ok_lines "a" "abc" "34 x" || stdfail 1

  run package_sh_list "/tmp/package.sh" list_2 "v" test_
  test_ok_lines "q" "xyz" "13 5" || stdfail 2

  rm /tmp/package.sh
}
