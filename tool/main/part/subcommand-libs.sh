#!/bin/sh

# FIXME: this is currently overriden by @Htd

main_var libs "$baseids" libs "$subcmd" "$subcmd"
libs=${libs//[,]/ }
$LOG notice : "Foo libs" "$libs"
test -n "$libs" && {
  lib_require $libs &&
  INIT_LOG=$LOG lib_init $libs || return
}
unset libs
#
