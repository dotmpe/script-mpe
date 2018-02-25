#!/usr/bin/env bats

load init
base=pd-lib
load main.inc

init

setup()
{
  source $lib/util.sh
  source $lib/main.lib.sh
}

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

# vim:ft=bash:
