#!/usr/bin/env bats

lib=${PREFIX}str
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
