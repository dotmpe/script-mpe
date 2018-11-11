#!/usr/bin/env bats

base=build-test.lib

load init

setup()
{
  init &&
  lib_load &&
  lib_load build-test setup-sh-tpl &&
  build_test_init
}

@test "$base: *_static tests target groups (specs)" {

skip
  component_test=words_to_lines
  run baseline_static
  { test_ok_nonempty &&
    test_lines $package_specs_baseline
  } || stdfail "baselines"

  component_test=words_to_lines
  run unit_tests_static
  { test_ok_nonempty &&
    test_lines $package_specs_units
  } || stdfail "units"

  component_test=words_to_lines
  run feature_tests_static
  { test_ok_nonempty &&
    test_lines $package_specs_features
  } || stdfail "features"
}


@test "$base: component-map: basename-id (default)" {

  test -n "$component_map"
  run $component_map some/file/name.ext
  test_ok_nonempty "name some/file/name.ext" || stdfail "$component_map"
}

@test "$base: component-map: static list: A." {

  export verbosity=4
  component_map_list=test/var/build-lib/map-list-1.list
  touch SrcFileA TestFileA

  run component_map_list SrcFileA
  test_ok_nonempty "Suite-Id:A:120 SrcFileA" || stdfail A.1
  run component_map_list TestFileA
  test_ok_nonempty "Suite-Id:A:120 TestFileA" || stdfail A.2

  rm SrcFileA TestFileA
}

@test "$base: component-map: static list: B." {

  export verbosity=4
  component_map_list=test/var/build-lib/map-list-1.list
  touch SrcFileB1 SrcFileB2 TestFileB

  run component_map_list SrcFileB2
  test_ok_nonempty "Suite-Id:B:121 SrcFileB2" || stdfail B.1.2
  run component_map_list SrcFileB1
  test_ok_nonempty "Suite-Id:B:121 SrcFileB1" || stdfail B.1.1
  run component_map_list TestFileB
  test_ok_nonempty "Suite-Id:B:121 TestFileB" || stdfail B.2

  rm SrcFileB1 SrcFileB2 TestFileB
}

@test "$base: component-map: static list: C." {

  export verbosity=4
  component_map_list=test/var/build-lib/map-list-1.list
  touch SrcFileC1 TestFileC1

  run component_map_list SrcFileC1
  test_ok_nonempty "Suite-Id:C:122 SrcFileC1" || stdfail C.1
  run component_map_list TestFileC1
  test_ok_nonempty "Suite-Id:C:122 TestFileC1" || stdfail C.2

  rm SrcFileC1 TestFileC1
}

@test "$base: component-map: static list: D." {

  export verbosity=4
  component_map_list=test/var/build-lib/map-list-1.list
  touch SrcFileD TestFileD1 TestFileD2

  run component_map_list SrcFileD
  test_ok_nonempty "Suite-Id:D:123 SrcFileD" || stdfail D.1
  run component_map_list TestFileD1
  test_ok_nonempty "Suite-Id:D:123 TestFileD1" || stdfail D.2

  rm SrcFileD TestFileD1 TestFileD2
}

@test "$base: component-map: static list: E." {

  skip "FIXME: query Id with blank tag"

  export verbosity=4
  component_map_list=test/var/build-lib/map-list-1.list
  touch SrcFileE TestFileE

  run component_map_list SrcFileE
  test_ok_nonempty "Suite-Id:E:124 SrcFileE" || stdfail E.1
  run component_map_list TestFileE
  test_ok_nonempty "Suite-Id:E:124 TestFileE" || stdfail E.2

  rm SrcFileE TestFileE
}


@test "$base: any-unit expects one test-file per given (suite) Id" {

  TODO build.lib any-unit unit-test
 
  package_specs_units='$id.foo $vid.bar'
  run any_unit Fancy-TestSuite:af91:x=y
  test_ok_empty || stdfail
}

@test "$base: component-tests: any-* testnames (default)" {
  
  TODO $base unit-test
}

@test "$base: project-test runs \$component_test_exec; for given/every tests" {

  TODO
  debug_testrun()
  {
    test -e "$1" || echo "$1"
  }
  component_test_exec=debug_testrun
  run project_test
  test_ok_nonempty || stdfail
}

@test "$base: project-tests " {

  TODO
  run project_tests "test/build-test-lib.bats"
  { test_ok_nonempty &&
    test_lines "test/build-test-lib.bats"
  } || stdfail
}
