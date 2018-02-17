#!/usr/bin/env bats

load helper
load vc
base=vc.sh

init

setup()
{
  . ./$base load-ext
  . ./util.sh load-ext
  lib_load os sys str std match vc
  setup_clean_git
}

@test ". $bin vc_dir/vc_gitdir - reports GIT dir in GIT checkout" {

  tmpd=$(pwd -P)

  # NOTE: reports relative dir
  run vc_dir
  { test_ok_nonempty &&
    test "${lines[@]}" = ".git"
  } || fail "1. Lines: ${lines[@]} ($tmpd)"

  run vc_gitdir
  { test_ok_nonempty &&
    test "${lines[@]}" = ".git"
  } || fail "2. Lines: ${lines[@]} ($tmpd)"

  # NOTE: does not report relative URL when in subdir
  mkdir -p sub-1/sub-1.1
  cd sub-1/sub-1.1
  run vc_gitdir
  { test_ok_nonempty &&
    test "${lines[@]}" = "$tmpd/.git"
  } || fail "3. Lines: ${lines[@]} ($tmpd)"
}

@test ". $bin vc_status" {

  run vc_stats
  test_ok_nonempty || fail 1
}

@test ". $bin vc_flags_git - " {

  run vc_flags_git
  { test_ok_nonempty && test "$(echo ${lines[@]})" = "(master)"
  } || fail 1

  vc.sh ps1

  mkdir -vp sub-1/sub-1.1
  cd sub-1/sub-1.1
  run vc_flags_git
  { test_ok_nonempty && test "$(echo ${lines[@]})" = "(master)"
  } || fail 2
}

@test ". $bin vc_stats" {

  run vc_stats
  test_ok_nonempty || fail 1

  #shopt -s extglob

  #run __vc_status
  #{ test_ok_nonempty &&
  #  fnmatch "$tmpd \[git:master +([0-9a-f])...\]" "${lines[*]}"
  #} || fail 1

  #mkdir -vp sub-1/sub-1.1
  #cd sub-1/sub-1.1
  #run __vc_status
  #{ test_ok_nonempty &&
  #  fnmatch "$tmpd \[git:master +([0-9a-f])...\]/sub-1/sub-1.1" "${lines[*]}"
  #} || fail 2


  #shopt -u extglob
}

@test ". $bin __vc_gitrepo - report a vendor/project repo ID-ish" {

  run __vc_gitrepo
  test $status -ne 0 \
    || fail "${status}"
  
  git remote add origin git@github.com:bvberkum/script-mpe.git
  run __vc_gitrepo
  test $status -eq 0 \
    || fail "__vc_gitrepo ret ${status}, lines: ${lines[@]}"
  test "${lines[@]}" = "bvberkum/script-mpe" \
    || fail "${lines[@]}"
}

# vim:ft=sh:
