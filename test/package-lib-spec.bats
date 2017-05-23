#!/usr/bin/env bats

load helper
base=package.lib

init
. $lib/util.sh


setup()
{
  lib_load package
}


@test "${lib}/${base} - lib loads" {

  func_exists package_lib_load
  func_exists package_basename
  func_exists update_package_json
  func_exists jsotk_package_sh_defaults
  func_exists update_package_sh
  func_exists update_temp_package
  func_exists update_package
  func_exists package_sh
  func_exists package_default_env
  func_exists package_sh_env
  func_exists package_sh_script
}


@test "${lib}/${base} - lib load sets env" {
  test -n "$PACKMETA" -a "$PACKMETA" = "package.yaml"
  test -n "$PACKMETA_BN" -a "$PACKMETA_BN" = "package"
  test -n "$PACKMETA_JS_MAIN" -a "$PACKMETA_JS_MAIN" = "./.package.main.json" ||
    fail "$PACKMETA_JS_MAIN"
  test -n "$PACKMETA_SH" -a "$PACKMETA_SH" = "./.package.sh"
  test -n "$package_id" -a "$package_id" = "script-mpe"
}


@test "${lib}/${base} - package-sh" {
  cd /tmp

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


@test "${lib}/${base} - package test/var dirs" {

  cd test/var/package/0
  unset package_id
  package_lib_load
  run package_sh id
  test_ok_nonempty "*id=script-mpe-test-0" || stdfail 1

}

@test "${lib}/${base} - package test/var/package/1 - main and secondary project" {

  cd test/var/package/1

  unset package_id
  package_lib_load
  run package_sh id key
  test_ok_nonempty "*id=script-mpe-test-1-a key=foo" || stdfail 2

  export package_id=script-mpe-test-1-b
  package_lib_load
  run package_sh id key
  test_ok_nonempty "*id=script-mpe-test-1-b key=bar" || stdfail 3

  # XXX: also allows non-typed entries but don't rely on this?
  export package_id=other
  package_lib_load
  run package_sh id key
  test_ok_nonempty "*id=other key=baz" || stdfail 4
}

