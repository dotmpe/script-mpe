#!/usr/bin/env bats

load init
base=git.lib

setup()
{
  init &&
  load assert &&
  lib_load git
}


@test "$base: lookup path default" {

  # Test dynamic part of lib-load hook
  eval PROJECT_DIR= PROJECTS=
  git_lib_load
  run echo "$PROJECT_DIR"
  { test_ok_nonempty 1 && test_lines "/srv/project-local"
  } || stdfail 1.

  #_run() { echo "$PROJECTS" | tr ':' '\n' ; } ; run _run

  run echo "$PROJECTS"
  { test_ok_nonempty 1 && test_lines \
"/srv/project-local:$HOME/project:/src/bitbucket.org/:/src/github.com/:/src/googlecode.com/:/src/local/"
  } || stdfail 2.
}

@test "$base: git-list searches \$PROJECTS for repositories (but doesn't check them)" {

  run git_src_info
  { test_ok_nonempty
  } || stdfail
}

@test "$base: git-src-info compiles path/repo table from \$PROJECTS with fixed columns: remote-name remote-url project-name account-handle vendor" {

  run git_src_info
  { test_ok_nonempty
  } || stdfail
}


@test "$base: htd git list, find, get, require, init" {
  true
}

@test "$base: htd git get-from" {
  true
}

@test "$base: htd git get-env" {
  true
}
