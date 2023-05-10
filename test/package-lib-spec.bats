#!/usr/bin/env bats

load init
base=package.lib

setup ()
{
  init &&
  load assert &&
  lib_require match package
}

teardown ()
{
  test ${package_lib_init:-1} -ne 0 || {
    package_env_unset && package_lib_unset &&
    package_lib_init= ENV_LIBS= package_lib_auto= package_lib_init
    unset package_lib_init
  }
  test "${package_id+"set"}" != "set" || unset -v package_id
}


@test "$base: lib-load sets env" {

  assert_equal "py" "$out_fmt"
  assert_equal ".meta" "$METADIR"
}


@test "$base: lib-init sets env" {

  package_lib_auto= lib_init package

  assert_equal "$ENV_LIBS"   "package"
  assert_equal "$LCACHE_DIR" "$METADIR/cache"
  assert_equal "$PACK_DIR"   "$METADIR/package"
  test -z "${package_id-}"
}


@test "$base: lib-init autoloads package meta" {

  lib_init package

  assert_equal "$PACKAGE_JSON"  ".meta/cache/package.json"
  assert_equal "$package_id"    "script-2008b-mpe"
  assert_equal "$PACK_JSON"     ".meta/package/$package_id.json"
  assert_equal "$PACK_SH"       ".meta/package/$package_id.sh"

  teardown

  package_lib_auto=1 lib_init package
}


@test "$base: package-sh (I)" {

  load stdtest
  lib_require sys-htd str-htd
  cd /tmp

  PACK_SH=package.sh

  echo "package_id=foo" > $PACK_SH
  run package_sh id
  test_ok_nonempty "id=foo" || stdfail 1

  echo "package_id=\"foo bar\" " > $PACK_SH
  run package_sh id
  test_ok_nonempty "id=\"foo bar\"" || stdfail 2.1

  echo "package_id=foo\ bar" > $PACK_SH
  run package_sh id
  test_ok_nonempty "id=\"foo bar\"" || stdfail 2.2

  echo "package_id='foo bar'" > $PACK_SH
  run package_sh id
  test_ok_nonempty "id=\"foo bar\"" || stdfail 2.3

  rm $PACK_SH
}


@test "$base: package-sh (II)" {

  load stdtest
  lib_require log std sys-htd str-htd
  lib_init package
  package_update_sh

  run package_sh id
  test_ok_nonempty "id=script-2008b-mpe" || stdfail 1
}


@test "$base: package test/var dirs" {
# FIXME: test var package 2: "Main is used as ID"
# FIXME: test var package 3: "Main is also ID"

  load stdtest
  lib_require log std sys-htd str-htd

  local i pwd=$PWD
  for i in 0 1
  do
    cd $pwd/test/var/package/$i
    lib_init package
    test -s "$PACKAGE_JSON"
    test -n "$package_id"
    package_update_json
    test -s "$PACK_JSON"
    package_update_sh
    test -s "$PACK_SH"

    run package_sh id
    test_ok_nonempty "id=script-bvb-test-$i*" || stdfail 2.$i

    teardown && cd "$pwd" && git clean -dfx test/var/package/$i
  done
}


@test "$base: package test/var/package/1 - main and secondary project" {

  load stdtest
  lib_require log std sys-htd str-htd

  cd test/var/package/1
  lib_init package
  test -s "$PACKAGE_JSON"
  package_update_json
  test -s "$PACK_JSON"
  package_update_sh
  test -s "$PACK_SH"

  run package_sh id key
  test_ok_nonempty "*id=script-bvb-test-1-a key=foo" || stdfail 2

  teardown
  export package_id=script-bvb-test-1-b
  lib_init package
  package_update_json
  test -s "$PACK_JSON"
  package_update_sh
  run package_sh id key
  test_ok_nonempty "*id=script-bvb-test-1-b key=bar" || stdfail 3

  # XXX: also allows non-typed entries but don't rely on this?
  #teardown
  #export package_id=other
  #lib_init package
  #package_update_json
  #test -s "$PACK_JSON"
  #package_update_sh
  #run package_sh id key
  #test_ok_nonempty "*id=other key=baz" || stdfail 4
}

@test "$base: package_sh_list" {

  load stdtest
  . test/var/package-1-tpl.sh
  echo "$package_1_tpl__1__contents" > /tmp/package.sh

  run package_sh_list "/tmp/package.sh" list_1 "" test_
  test_ok_lines "a" "abc" "34 x" || stdfail 1

  run package_sh_list "/tmp/package.sh" list_2 "v" test_
  test_ok_lines "q" "xyz" "13 5" || stdfail 2

  rm /tmp/package.sh
}
