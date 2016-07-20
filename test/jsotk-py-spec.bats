#!/usr/bin/env bats

load helper
base=jsotk.py

init



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

@test "${bin} from-args l[]=1 l[]=2 l[2]=3" "update indices" {
  TODO "update at index with jsotk"
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test "${lines[*]}" = '{"l": [1, 3]}'
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

@test "${bin} compare src/dest formats for test/var/1.*" {
  jsotk_from_kv_test()
  {
    printf "foo/2[2]=more\nfoo/2[3]=items\n" | jsotk.py from-kv - || return $?
  }
  run jsotk_from_kv_test
  test ${status} -eq 0 || fail "Output: ${lines[*]}"
  test "${lines[*]}" = '{"foo": {"2": [null, null, "more", "items"]}}'
}

@test "${bin} can use objectpath" {

  # Select main attribute of all objects under root
  run jsotk.py objectpath \
    test/var/jsotk/2.yaml \
    '$.*[@.main]'
  test ${status} -eq 0 || fail "Output: ${lines[*]}"
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

# Note: docopts does not support merge arguments, so implemented merge-one
# as relief

@test "${bin} --list-update merge ..." {
  TODO "implement list item updates for from-args"
}

@test "${bin} --list-update merge-one ..." {
  #jsotk.py from-args 'list[1]=1' 'list[2]/foo=3' > /tmp/in1.json
  echo '{"list": [1, {"foo": 3}]}' >/tmp/in1.json
  #jsotk.py from-args 'list[2]/foo=2' > /tmp/in2.json
  echo '{"list": [1, {"foo": 2}]}' >/tmp/in2.json
  run $bin --list-update merge-one /tmp/in1.json /tmp/in2.json /tmp/out.json
  test ${status} -eq 0 || {
    echo ${lines[*]} >> $BATS_OUT
    fail "Output above. "
  }
  test "$(cat /tmp/out.json)" = '{"list": [1, {"foo": 2}]}'
}

@test "${bin} --list-union merge-one ... (default)" {
  jsotk.py from-args 'foo/bar[]=1' 'foo/bar[]=3' > /tmp/in1.json
  jsotk.py from-args 'foo/bar[]=2' > /tmp/in2.json
  run $bin merge-one /tmp/in1.json /tmp/in2.json /tmp/out.json
  test ${status} -eq 0
  test "$(cat /tmp/out.json)" = '{"foo": {"bar": [1, 3, 2]}}'
}

@test "${bin} update I - simple dict key" {
  jsotk_merge_test()
  {
    echo newkey=value | jsotk.py -I fkv update test/var/jsotk/1.yaml - || {
      git co test/var/jsotk/1.yaml
      return $?
    }
    cat test/var/jsotk/1.yaml | jsotk.py yaml2json -
    git co test/var/jsotk/1.yaml
  }
  run jsotk_merge_test
  test ${status} -eq 0 || fail "Output: ${lines[*]}"
  echo "${lines[*]}" >/tmp/123
  test "${lines[*]}" = '{"newkey": "value", "foo": {"1": "bar", "3": {"1": "subs"}, "2": ["list", "with", "items"]}}' \
    || fail "output '${lines[*]}'"
}

@test "${bin} merge/update - output-prefix" {
  jsotk_output_prefix_test()
  {
    jsotk.py --output-prefix pa/th merge - test/var/jsotk/3.yaml || return $?
  }
  run jsotk_output_prefix_test
  test ${status} -eq 0
  test "${lines[*]}" = '{"pa": {"th": {"foo": [1, 2], "bar": true}}}'
}

@test "${bin} update II - nested dict with list index" {

  TODO "fix ${bin} update testing"

  jsotk_update_3_test()
  {
    printf "foo/2[2]=more\nfoo/2[3]=items\n" \
      | jsotk.py --list-update update - test/var/jsotk/1.yaml || return $?
  }
  run jsotk_update_3_test
  test ${status} -eq 0
  test "${lines[*]}" = \
  '{"foo": {"1": "bar", "3": {"1": "subs"}, "2": ["list", "with", "more", "items"]}}'

  jsotk_update_3b_test()
  {
    printf "foo/2[2]=more\nfoo/2[3]=items\n" \
    | jsotk.py --list-union update - test/var/jsotk/1.yaml || return $?
  }
  run jsotk_update_3b_test
  test ${status} -eq 0
  test "${lines[*]}" = \
  '{"foo": {"1": "bar", "3": {"1": "subs"}, "2": ["list", "with", "more", "items"]}}'
}

@test "${bin} -O fkv  path  test/var/jsotk/1.json  foo/2" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0 || fail "Output: ${lines[*]}"
  test "${lines[*]}" = "__0=list __1=with __2=items" \
    || fail "Output: ${lines[*]}"
}

# vim:ft=sh:
