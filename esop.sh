#!/bin/sh

esop_source="$_"

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
  esop_init || return $(( $? - 1 ))
  local scriptname=esop base="$(basename "$esop_source" .sh)"
  #\ verbosity=7
  #choice_debug=1
  debug "Init ok"
  case "$base" in
    $scriptname )
      run_subcmd "$@" || return $?
      ;;
    * )
      error "not a frontend for $base" 1
      ;;
  esac
}

esop_init()
{
  test -z "$__load_lib" || return 1
  test -n "$LIB" || LIB=$HOME/bin
  . $LIB/main.sh
  . $LIB/util.sh
  # -- esop box init sentinel --
}

esop_load()
{
  local __load_lib=1
  . $LIB/match.sh load-ext
  # -- esop box load sentinel --
}


# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )
  # Ignore 'load-ext' sub-command
  case "$1" in load-ext ) ;; * )
    esop_main "$@" || exit $?
  ;; esac
;; esac
