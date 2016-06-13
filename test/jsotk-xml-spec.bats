#!/usr/bin/env bats

load helper
base=jsotk.py

init



@test "${bin} dump \$testf -O yaml --pretty" {

  testf=test/var/jsotk/xml-1.xml
  run eval $BATS_TEST_DESCRIPTION
  test ${status} -eq 0 || fail "Output: ${lines[*]}"
  
  TODO "specs for (XML-to-YAML/JSON mode-1):"

  expectf=test/var/jsotk/xml-1.yaml
  tmpf
  test -n "$tmpf"
  eval $BATS_TEST_DESCRIPTION > $tmpf
  test -n "$tmpf"
  file_equal $expectf $tmpf || {
    diff $expectf $tmpf >> $BATS_OUT || noop
    fail "Mismatch: $expectf $tmpf, output does not match"
  }
}

@test "${bin} dump test/var/jsotk/xml-2.xml" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0 || fail "Output: ${lines[*]}"
  TODO "YAML/JSON-to-XML mode-2"
}

@test "${bin} dump test/var/jsotk/xml-1.yaml -O xml" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0 || fail "Output: ${lines[*]}"
  TODO "YAML/JSON-to-XML mode-1"
}

@test "${bin} dump test/var/jsotk/xml-2.yaml -O xml" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0 || fail "Output: ${lines[*]}"
  TODO "YAML/JSON-to-XML mode-2"
}


