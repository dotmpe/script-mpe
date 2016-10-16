#!/bin/sh

set -e


# FIXME: comment format:
# [return codes] [exit codes] func-id [flags] pos-arg-id.. $name-arg-id..
# Env: $name-env-id
# Description.


lib_load()
{
  test -n "$1" || set -- sys os std stdio str src
  while test -n "$1"
  do
    . $scriptdir/$1.lib.sh
    shift
  done

  #. $scriptdir/match.sh
  #. $scriptdir/doc.lib.sh
  #. $scriptdir/table.lib.sh
}

util_init()
{
  lib_load
  sys_load
  str_load
}


case "$0" in "" ) ;; "-"* ) ;; * )

  test -z "$__load_lib" || set -- "load-ext"
  case "$1" in
    load-* ) ;; # External include, do nothing

    * ) # Setup SCRIPTPATH and include other scripts

        test -n "$scriptdir"
        util_init

  ;; esac

;; esac

