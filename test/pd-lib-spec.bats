#!/usr/bin/env bats

load helper
base=pd-lib
load main.inc

init
source $lib/util.sh
source $lib/main.lib.sh


@test "load Pd core+ext scripts" {

  . ${lib}/projectdir.sh load-ext
  . ${lib}/projectdir.lib.sh load-ext
  . ${lib}/projectdir-bats.inc.sh
  . ${lib}/projectdir-fs.inc.sh
  . ${lib}/projectdir-git-versioning.inc.sh
  . ${lib}/projectdir-git.inc.sh
  . ${lib}/projectdir-grunt.inc.sh
  . ${lib}/projectdir-lizard.inc.sh
  . ${lib}/projectdir-make.inc.sh
  . ${lib}/projectdir-npm.inc.sh
  . ${lib}/projectdir-vagrant.inc.sh
}

setup()
{
  . ${lib}/projectdir.lib.sh load-ext
  util_init
}

@test "pd - finddoc" {

  pd=.projects.yaml
  run pd_finddoc
  (
    test $status -eq 0
    fnmatch "*Pd prefix: *, realdir: $HOME Before: */*" "${lines[*]}"
  ) || {
    diag "Status: $status"
    diag "Out: ${lines[*]}"
    fail "finddoc"
  }
}


