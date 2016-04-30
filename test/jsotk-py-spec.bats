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

@test "${bin} compare src/dest formats for test/var/1.*" {

  testf=test/var/jsotk/1.yaml
  testkv=test/var/jsotk/1.txt
  testjs=test/var/jsotk/1.json

  gen_y_js=/tmp/gen-y.json
  jsotk.py --pretty yaml2json $testf > $gen_y_js
  diff -q $gen_y_js $testjs

# TODO: format as flat-kv
#  gen_y_sh=/tmp/gen-y.sh
#  jsotk.py -I yaml to-flat-kv $testf > $gen_y_sh
#  diff -q $gen_y_sh $testkv

  gen_sh_js=/tmp/gen-sh.json
  jsotk.py --pretty from-flat-kv $testkv > $gen_sh_js
  diff -q $gen_sh_js $testjs

  gen_sh_y=/tmp/gen-sh.yaml
  jsotk.py -O yaml --pretty from-flat-kv $testkv > $gen_sh_y
  diff -q $gen_sh_y $testf

# TODO: format as flat-kv
#  gen_js_sh=/tmp/gen-js.sh
#  jsotk.py to-flat-kv $testjs > $gen_js_sh
#  diff -q $gen_js_sh $testkv

  gen_js_y=/tmp/gen-js.yaml
  jsotk.py --pretty json2yaml $testjs > $gen_js_y
  diff -q $gen_js_y $testf

}


