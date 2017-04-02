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

  func_exists package_load
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


