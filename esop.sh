#!/bin/sh
esop_src="$_"

set -e



version=0.0.0+20150911-0659 # script.mpe


esop_man_1__version="Version info"
esop__version()
{
  echo "$(cat $PREFIX/bin/.app-id)/$version"
}
esop_als__V=version


esop_man_1__x=abc
esop_run__x=abc
esop_spc__x="x [ARG..]"
esop__x()
{
  note "Running x"
}

esop_main()
{
  local \
      scriptname=esop \
      base="$(basename $0 ".sh")"
  case "$base" in
    $scriptname )
      local LIB="$(dirname $0)"
      esop_init || return $?
      run_subcmd "$@" || return $?
      ;;
    * )
      echo "$scriptname: not a frontend for $base"
      exit 1
      ;;
  esac
}

esop_init()
{
  . $LIB/main.sh
  . $LIB/std.lib.sh
  . $LIB/str.lib.sh
  . $LIB/util.sh
  . $LIB/box.init.sh
  box_run_sh_test
  # -- esop box init sentinel --
}

esop_load()
{
  local __load_lib=1
  . $LIB/match.sh load-ext
  # -- esop box load sentinel --
}


case "$0" in "" ) ;; "-"* ) ;; * )
  test -z "$__load_lib" || set -- "load-ext"
  case "$1" in load-ext ) ;; * )
    esop_main "$@" || exit $?
  ;; esac
;; esac
