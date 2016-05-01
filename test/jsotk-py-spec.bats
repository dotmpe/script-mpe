#!/usr/bin/env bats

load helper
base=jsotk.py

init_lib
init_bin

. $lib/str.lib.sh


@test "${bin} -h" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
}

@test "${bin} from-args foo=bar" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test "${lines[0]}" = '{"foo": "bar"}'
}

@test "${bin} from-args foo[]=bar foo[]=123" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test "${lines[0]}" = '{"foo": ["bar", 123]}'
}

@test "${bin} from-args a/b/c=1 a/d[]=2 a/d[]=3" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test "${lines[0]}" = '{"a": {"b": {"c": 1}, "d": [2, 3]}}'
}

@test "${bin} compare src/dest formats for test/var/1.*" {

  testf=test/var/jsotk/1.yaml
  testp=test/var/jsotk/1.txt
  testkv=test/var/jsotk/1.sh
  testjs=test/var/jsotk/1.json

  gen_y_js=/tmp/gen-y.json
  jsotk.py --pretty yaml2json $testf > $gen_y_js
  echo >> $gen_y_js
  diff -q $gen_y_js $testjs
  gen_y_p=/tmp/gen-y.txt
  jsotk.py --no-indices -I yaml to-kv $testf | sort > $gen_y_p
# XXX: diff -q $gen_y_p $testp
  gen_y_sh=/tmp/gen-y.sh
  jsotk.py -I yaml to-flat-kv $testf | sort > $gen_y_sh
  diff -q $gen_y_sh $testkv

  gen_p_js=/tmp/gen-paths.json
  jsotk.py --pretty from-kv $testp > $gen_p_js
  echo >> $gen_p_js
  diff -q $gen_p_js $testjs
  gen_p_y=/tmp/gen-paths.yaml
  jsotk.py -O yaml --pretty from-kv $testp > $gen_p_y
  diff -q $gen_p_y $testf

  gen_js_sh=/tmp/gen-js.sh
  jsotk.py to-flat-kv $testjs | sort > $gen_js_sh
  diff -q $gen_js_sh $testkv

  gen_js_y=/tmp/gen-js.yaml
  jsotk.py --pretty json2yaml $testjs > $gen_js_y
  diff -q $gen_js_y $testf
}

@test "${bin} can use objectpath" {

  # Select main attribute of all objects under root
  run jsotk.py objectpath \
    test/var/jsotk/2.yaml \
    '$.*[@.main]'
  test ${status} -eq 0
  test '"third-type"' = "${lines[*]}" 

  # Select all objects under root with main attribute
  run jsotk.py objectpath \
    test/var/jsotk/2.yaml \
    '$.*[@.main is not None]'
  test ${status} -eq 0
  test '{"main": "third-type", "type": "third-type", "manifest": [1, 2, 3]}' = "${lines[*]}" 

  # Recursively select all manifest attribute list values
  run jsotk.py objectpath \
    test/var/jsotk/2.yaml \
    '$..*[@.manifest]'
  test ${status} -eq 0
  test "${lines[0]}" = "[1]"
  test "${lines[*]}" = "[1] [1, 2, 3] [2, 4, 5] [5]"
}

