#!/bin/sh

main_var libs "$baseids" libs "$subcmd" "$subcmd"
test -n "$libs" && {
  lib_require $libs || return
  INIT_LOG=$LOG lib_init $libs || return
}
unset libs
#
