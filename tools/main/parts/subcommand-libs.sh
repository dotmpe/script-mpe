#!/bin/sh

subcommand_libs="$(try_value $subcmd libs $base)" || subcommand_libs=$subcmd
test -n "$subcommand_libs" || return
lib_require $subcommand_libs || return
INIT_LOG=$LOG lib_init $subcommand_libs || return
#
