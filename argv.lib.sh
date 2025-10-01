#!/usr/bin/env bash

argv_lib__load ()
{
  :
}

argv_rev_from ()
{
  : note "See also sys-rarr* to reverse copy between arrays"
  : input "${1:?$FUNCNAME: Argument source array}"
  local -n _argv_rev_from=${1}
  TODO
}

argv_rev_to ()
{
  : note "See also sys-rarr* to reverse copy between arrays"
  : input "${1:?$FUNCNAME: Argument dest array}"
  : src argv.lib.sh
  #local -n _argv_rev_to=${1}
  #TODO
  (($#-1)) || return ${_E_MA:-194}
  local -n _argv_rev_to=${@: -1}
  local _i
  for ((_i=$#-1;_i>0;_i--))
  do
    _argv_rev_to+=( "${@:_i:1}" )
  done
}
