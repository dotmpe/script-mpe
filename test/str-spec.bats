#!/usr/bin/env bats

load helper

test -z "$PREFIX" && lib=./str.lib || lib=$PREFIX/bin/str.lib
func=mkvid

source $lib.sh


@test "$lib $func can make ID from path" {
    mkvid "/var/lib"
    test "$vid" = "_var_lib"
    mkvid "/var/lib/"
    test "$vid" = "_var_lib_"
}

@test "$lib $func cleans up ID from path" {
    mkvid "/var//lib//"
    test "$vid" = "_var_lib_"
    mkvid "/var//lib"
    test "$vid" = "_var_lib"
}

@test "$lib $func cleans up ID from path (II)" {
    skip "TODO implement/test with dir/./.. etc"
}

@test "$lib fnmatch" {
  fnmatch "f*o" "foo" || test
  fnmatch "test" "test" || test
  fnmatch "*test*" "test" || test
  fnmatch "*test" "123test" || test
  fnmatch "test*" "test123" || test
}

@test "$lib fnmatch (spaces)" {
  fnmatch "* test" "123 test" || test
  fnmatch "test *" "test 123" || test
  fnmatch "*test*" " test " || test
  fnmatch "./file.sh: line *: test" "./file.sh: line 1234: test" || test
  tmpd
  errmsg="[htd.sh:today] Error: Dir $tmpd/journal must exist"
  fnmatch "*Error*Dir $tmpd/journal must exist*" "$errmsg"
}

