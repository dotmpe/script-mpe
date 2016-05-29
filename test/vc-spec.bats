#!/usr/bin/env bats

load helper
base=vc.sh
init


@test "$bin no arguments no-op" {
  run $bin
  test $status -eq 0
}

@test "$bin help" "prints help" {
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
}

@test "$bin commands" "prints commands" {
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
}

@test "$bin version" "prints version" {
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
}

@test "$bin list-prefixes" {
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
}

@test "$bin uf" "prints unversioned files" {
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
}

@test "$bin ufx" "prints unversioned and excluded files" {
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
}

@test "$bin ps1" {
  cd /tmp
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  test "/tmp" = "${lines[*]}"
}

@test "$bin screen" {
  cd /tmp
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  test "/tmp" = "${lines[*]}"
}

setup_clean_git()
{
  local tmpd=/tmp/script-mpe-vc-bats-$(uuidgen)
  mkdir -vp $tmpd
  cd $tmpd
  git init
  touch .gitignore
  git add .
  git ci -m Init
}

@test "$bin bits" {

  export GIT_PS1_DESCRIBE_STYLE=(contains)
  export GIT_PS1_SHOWSTASHSTATE=1
  export GIT_PS1_SHOWDIRTYSTATE=1
  export GIT_PS1_SHOWUNTRACKEDFILES=1

  local owd=$(pwd)
  setup_clean_git
  local twd=$(pwd)

  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  fnmatch $twd' \[git:master +([0-9a-f])...\]' "${lines[*]}"

  mkdir doc
  cd doc
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0

  fnmatch $twd' \[git:master +([0-9a-f])...\]/doc' "${lines[*]}"

  cd $twd
  echo ignore > .gitignore

  #diag "$(git status)"
  #diag "${lines[*]}"

  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  fnmatch $twd' \[git:master\* +([0-9a-f])...\]' "${lines[*]}"

  cd doc
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  fnmatch $twd' \[git:master\* +([0-9a-f])...\]/doc' "${lines[*]}"

  cd $twd
  touch README

  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  fnmatch $twd' \[git:master\*~ +([0-9a-f])...\]' "${lines[*]}"

  cd doc
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  fnmatch $twd' \[git:master\*~ +([0-9a-f])...\]/doc' "${lines[*]}"

  cd $twd
  touch CHANGELOG
  git add README

  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  fnmatch $twd' \[git:master\*\+~ +([0-9a-f])...\]' "${lines[*]}"

  cd doc
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  fnmatch $twd' \[git:master\*\+~ +([0-9a-f])...\]/doc' "${lines[*]}"
}


