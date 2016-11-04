#!/usr/bin/env bats

base=finfo.py

load helper
init


setup() {
  
  tmpd
  # TODO: use test/var/example dir
  rsync -avzui test/var/ $tmpd
  cd $tmpd
}

teardown() {
  test -z "$tmpd" -o ! -e "$tmpd" || rm -rf $tmpd
}


@test "$bin - no arguments prints usage" {

  run $bin
  test $status -eq 1
}


@test "$bin --name - sets a path prefix context" {

  run $bin --name foo-dir pd/
}


@test "$bin --env - sets a prefix context with value from env" {

  tmpd
  cd $tmpd
  run $bin --env HTDIR=htdocs htdocs
}


@test "$bin --update - creates Tauxs INode records" {

  tmpd
  cd $tmpd
  run $bin --update --env htdocs=HTDIR htdocs
}

