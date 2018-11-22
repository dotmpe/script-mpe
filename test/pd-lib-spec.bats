#!/usr/bin/env bats

load init
base=pd-lib
#load main.inc

init
. $scriptpath/util.sh


setup()
{
  lib_load projectdir
}

@test "pd - finddoc" {

  pd=.projects.yaml
  export verbosity=7
  run pd_finddoc
  {
    test $status -eq 0 &&
    fnmatch "*Pd prefix: *, realdir: $HOME Before: */*" "${lines[*]}"
  } || stdfail
}

# vim:ft=bash:
