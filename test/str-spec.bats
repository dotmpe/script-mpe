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
    TODO "implement/test with dir/./.. etc"
}

