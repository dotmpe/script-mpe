#!/usr/bin/env bats

load init
base=pd-lib

init

setup()
{
  main_inc=$SHT_PWD/var/sh-src-main-mytest-funcs.sh &&
  . $main_inc &&
  source $scriptpath/util.sh &&
  source $scriptpath/main.lib.sh
}

@test "load Pd core+ext scripts" {

  . ${scriptpath}/projectdir.sh load-ext
  . ${scriptpath}/projectdir.scriptpath.sh load-ext
  . ${scriptpath}/projectdir-bats.inc.sh
  . ${scriptpath}/projectdir-fs.inc.sh
  . ${scriptpath}/projectdir-git-versioning.inc.sh
  . ${scriptpath}/projectdir-git.inc.sh
  . ${scriptpath}/projectdir-grunt.inc.sh
  . ${scriptpath}/projectdir-lizard.inc.sh
  . ${scriptpath}/projectdir-make.inc.sh
  . ${scriptpath}/projectdir-npm.inc.sh
  . ${scriptpath}/projectdir-vagrant.inc.sh
}

# vim:ft=bash:
