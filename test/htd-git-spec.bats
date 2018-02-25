#!/usr/bin/env bats

base=htd
load init
init
pwd=$(cd .;pwd -P)


version=0.0.4-dev # script-mpe

setup() {
  scriptname=test-$base
  #. $ENV
}

@test "$bin git-remote" {
  run htd git-remote
  test_ok_nonempty || stdfail
}

@test "$bin git-remote dotmpe" {
  # XXX: require_env ssh
  run htd git-remote dotmpe
  test_ok_nonempty || stdfail
}

@test "$bin git-remote dotmpe abc" {
  export verbosity=0
  run htd git-remote dotmpe abc
  { test_ok_nonempty &&
    fnmatch *"dotmpe:domains/dotmpe.com/htdocs/git/abc" "${lines[*]}"
  } || stdfail
}

@test "$bin git-remote info dotmpe abc" {
  export verbosity=0
  run htd git-remote info dotmpe abc
  { test_ok_nonempty &&
  fnmatch *"remote.dotmpe.git.url=dotmpe:domains/dotmpe.com/htdocs/git/abc remote.dotmpe.scp.url=dotmpe:domains/dotmpe.com/htdocs/git/abc.git remote.dotmpe.repo.dir=domains/dotmpe.com/htdocs/git/abc.git remote.dotmpe.hostinfo=dotmpe" "${lines[*]}"
  } || stdfail
}

@test "$bin git-remote url dotmpe abc" {
  export verbosity=0
  run htd git-remote url dotmpe abc
  { test_ok_nonempty &&
    fnmatch *"dotmpe:domains/dotmpe.com/htdocs/git/abc" "${lines[*]}"
  } || stdfail
}
