#!/usr/bin/env bats

load helper
base=pd-lib
#load main.inc

init
. $lib/util.sh


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
