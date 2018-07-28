#!/usr/bin/env bats

load init
base=jsotk.py

init


setup()
{
  testf=test/var/jsotk/1.yaml
  testp=test/var/jsotk/1.txt
  testkv=test/var/jsotk/1.sh
  testjs=test/var/jsotk/1.json
}

teardown()
{
  # reset changes
  git checkout test/var/jsotk
}


@test "${bin} -h" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
}


# Test simple JSON creation

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

@test "${bin} from-args l[]=1 l[]=2 l[1]=3" "update at indices" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test "${lines[*]}" = '{"l": [3, 2]}' \
    || fail "Out: ${lines[*]}"
}


# Compare var. file-format conversions

@test "${bin} compare src/dest formats for test/var/1.* [A-2. YAML to JSON]" {

  gen_y_js=/tmp/gen-y.json
  jsotk.py --pretty --ignore-alias yaml2json $testf > $gen_y_js
  echo >> $gen_y_js
  diff $gen_y_js $testjs
}

@test "${bin} compare src/dest formats for test/var/1.* [A-3. YAML to path/value lines]" {
  skip "TODO: A-3, file-1: Preserve order; foo/3/1=subs inserted before foo/2"
  gen_y_p=/tmp/gen-y.txt
  jsotk.py --no-indices -I yaml to-kv $testf > $gen_y_p
  diff $gen_y_p $testp
}

@test "${bin} compare src/dest formats for test/var/1.* [A-4. YAML to shell-var lines]" {
  gen_y_sh=/tmp/gen-y.sh
  jsotk.py -I yaml to-flat-kv $testf | sort > $gen_y_sh
  diff $gen_y_sh $testkv
}

@test "${bin} compare src/dest formats for test/var/1.* [C-2. path/value lines to JSON]" {

  gen_p_js=/tmp/gen-paths.json
  jsotk.py --pretty --ignore-alias from-kv $testp > $gen_p_js
  echo >> $gen_p_js
  diff $gen_p_js $testjs
}

@test "${bin} compare src/dest formats [C-2b. path/value lines stdin to JSON stdout]" {
  jsotk_from_kv_test()
  {
    printf "foo/2[2]=more\nfoo/2[3]=items\n" | jsotk.py from-kv - || return $?
  }
  run jsotk_from_kv_test
  test ${status} -eq 0 || fail "Output: ${lines[*]}"
  test "${lines[*]}" = '{"foo": {"2": [null, "more", "items"]}}'
}

@test "${bin} compare src/dest formats for test/var/1.* [C-1. path/value lines to YAML]" {

  skip "TODO: C-1, file 1; same as B1 and A3. preserve order"
  gen_p_y=/tmp/gen-paths.yaml
  jsotk.py --ignore-alias -O yaml --pretty from-kv $testp > $gen_p_y
  diff $gen_p_y $testf
}

@test "${bin} compare src/dest formats for test/var/1.* [B-4. JSON to var-lines]" {

  gen_js_sh=/tmp/gen-js.sh
  jsotk.py --ignore-alias to-flat-kv $testjs | sort > $gen_js_sh
  diff $gen_js_sh $testkv
}

@test "${bin} compare src/dest formats for test/var/1.* [B-1. JSON to YAML]" {

  skip "TODO: B-1, file 1; preserve order, same as A-3 fconf; should be foo/3 after foo/2"
  gen_js_y=/tmp/gen-js.yaml
  jsotk.py --pretty json2yaml $testjs > $gen_js_y
  diff $gen_js_y $testf
}



@test "${bin} can use objectpath" {

  # Select main attribute of all objects under root
  run jsotk.py objectpath test/var/jsotk/2.yaml '$.*[@.main]'
  { test ${status} -eq 0 && test '"third-type"' = "${lines[*]}" 
  } || stdfail 1

  # Select all objects under root with main attribute
  run jsotk.py objectpath test/var/jsotk/2.yaml '$.*[@.main is not None]'
  { test ${status} -eq 0 &&
    test '{"main": "third-type", "type": "third-type", "manifest": [91, 2, 3]}' = "${lines[*]}"
  } || stdfail 2

  # Recursively select all manifest attribute list values
  run jsotk.py objectpath test/var/jsotk/2.yaml '$..*[@.manifest]'
  { test ${status} -eq 0 &&
    test "${lines[2]}" = "[2, 4, 5]" &&
    test "${lines[3]}" = "[5]"
  } || stdfail 3

  # FIXME: bug in bats?
  #test "${lines[0]}" = "[91]" &&
  #test "${lines[1]}" = "[91, 2, 3]" &&
  #test "${lines[*]}" = "[91] [91, 2, 3] [2, 4, 5] [5]"
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

# FIXME:
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
  { test_ok_nonempty &&
    test "${lines[*]}" = '{"newkey": "value", "foo": {"1": "bar", "3": {"1": "subs"}, "2": ["list", "with", "items"]}}'
  } || fail "output '${lines[*]}'"
}

@test "${bin} merge/update - output-prefix" {
  jsotk_output_prefix_test()
  {
    jsotk.py -q --output-prefix pa/th merge - test/var/jsotk/3.yaml || return $?
  }
  run jsotk_output_prefix_test
  { test_ok_nonempty &&
    test "${lines[*]}" = '{"pa": {"th": {"foo": [1, 2], "bar": true}}}'
  } || stdfail
}

@test "${bin} update II - nested dict with list index" {

  TODO "fix ${bin} update testing"

  jsotk_update_3_test()
  {
    printf "foo/2[2]=more\nfoo/2[3]=items\n" \
      | jsotk.py --list-update update - test/var/jsotk/1.yaml || return $?
  }
  run jsotk_update_3_test
  { test_ok_nonempty &&
    test "${lines[*]}" = \
      '{"foo": {"1": "bar", "3": {"1": "subs"}, "2": ["list", "with", "more", "items"]}}'
  } || stdfail 1

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


@test "${bin} -O fkv path test/var/jsotk/1.json foo/2" {
# TODO: test with -q
  run $BATS_TEST_DESCRIPTION
  { test_ok_nonempty &&
    test "${lines[*]}" = "__0=list __1=with __2=items" 
  } || fail "Output: ${lines[*]}"
}


@test "${bin} path - can check path data type or for insertable paths" {

  ${bin} path --is-str test/var/jsotk/4.json foo/1
  ${bin} path --is-int test/var/jsotk/4.json foo/1 && fail "1 int"
  ${bin} path --is-bool test/var/jsotk/4.json foo/1 && fail "1 bool"
  ${bin} path --is-obj test/var/jsotk/4.json foo/1 && fail "1 obj"
  ${bin} path --is-list test/var/jsotk/4.json foo/1 && fail "1 list"
  # FIXME: jsotk path is-new and is-null
  #${bin} path --is-new test/var/jsotk/4.json foo/1 && fail "1 new"
  #${bin} path --is-null test/var/jsotk/4.json foo/1 && fail "1 null"

  ${bin} path --is-str test/var/jsotk/4.json foo/2 && fail "2 str"
  ${bin} path --is-int test/var/jsotk/4.json foo/2 && fail "2 int"
  ${bin} path --is-bool test/var/jsotk/4.json foo/2 && fail "2 bool"

  #FIXME:
  #${bin} path --is-obj test/var/jsotk/4.json foo/2 && fail "2 obj"
  #${bin} path --is-list test/var/jsotk/4.json foo/2
  #${bin} path --is-new test/var/jsotk/4.json foo/2 && fail "2 new"
  #${bin} path --is-null test/var/jsotk/4.json foo/2 && fail "2 null"

  ${bin} path --is-str test/var/jsotk/4.json foo/3 && fail "3 str"
  ${bin} path --is-int test/var/jsotk/4.json foo/3 && fail "3 int"
  ${bin} path --is-bool test/var/jsotk/4.json foo/3 && fail "3 bool"
  ${bin} path --is-obj test/var/jsotk/4.json foo/3
  ${bin} path --is-list test/var/jsotk/4.json foo/3 && fail "3 list"

  ${bin} path --is-new test/var/jsotk/4.json foo/4

  ${bin} path --is-int test/var/jsotk/4.json foo/3/2

  ${bin} path --is-bool test/var/jsotk/4.json foo/3/3
}

@test "${bin} update - YAML aliased data is updated by reference" {
  
  dest=test/var/jsotk/5-1.yaml
  src1=test/var/jsotk/5-2.yaml
  src2=test/var/jsotk/5-3.yaml
  src3=test/var/jsotk/5-4.yaml

  run ${bin} update --list-union $dest $src1 $src2
  test_ok_empty || stdfail

  # We'd expect mydict/entries to have two items, except we end up with one
  # because of the YAML alias. jsotk_lib deep-update/-union has entry updated
  # before the entries list is merged. so by the time it is doing the union,
  # the new entry is already in the list, in place of the original entry. The
  # original data is gone, its too late for a list union.

  # Lets verify this, and count the entries.
  run ${bin} objectpath $dest 'count($.mydict.entries)'
  test_ok_nonempty || stdfail 2.1
  test "${lines[0]}" = "1" || stdfail 2.2
  git checkout $dest

  # It does not matter if we add files or merge with non-aliased files. The dest
  # file is still loaded with aliased YAML data to start with
  run ${bin} update --list-union $dest $src1 $src2
  test_ok_empty || stdfail 3
  run ${bin} objectpath $dest 'count($.mydict.entries)'
  test_ok_nonempty || stdfail 4.1
  test "${lines[0]}" = "1" || stdfail 4.2
  git checkout $dest

  # What does help is destroying the aliased entry, by overwriting with an
  # empty entry first. Since deep-update/-union does not move over the aliases
  # (I suppose, at least explicitly) the aliases in src's are not an issue.
  run ${bin} update --list-union $dest $src3 $src2 $src1
  test_ok_empty || stdfail 5
  run ${bin} objectpath $dest 'count($.mydict.entries)'
  test_ok_nonempty || stdfail 6.1
  test "${lines[0]}" = "3" || stdfail 6.2
}


@test "${bin} update - YAML aliased data is updated by reference (II)" {
  
  dest=test/var/jsotk/5-1.yaml
  src1=test/var/jsotk/5-2.yaml
  src2=test/var/jsotk/5-3.yaml

  # Lets try another solution, clear-paths is not a proper path lookup yet,
  # but should handle simple dicts.
  run ${bin} update --list-union --clear-paths mydict/entry $dest $src1 $src2
  test_ok_empty || stdfail

  # Count the entries again. We have a proper union now.
  run ${bin} objectpath $dest 'count($.mydict.entries)'
  test_ok_nonempty || stdfail 2.1
  test "${lines[0]}" = "2" || stdfail 2.2
}


# vim:ft=sh:
