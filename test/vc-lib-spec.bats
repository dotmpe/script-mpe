#!/usr/bin/env bats

load init
base=vc.lib

setup()
{
  init && load vc-setup &&
  lib_load=1 . ./vc.sh &&
  lib_load match vc-htd &&
  #. ./vc.sh &&
  vc_setup_clean_git
}

@test "${base}: vc_dir/vc_gitdir - reports GIT dir in GIT checkout" {

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

@test "${base}: vc_status" {

  run vc_stats
  test_ok_nonempty || fail 1
}

@test "${base}: vc_flags_git - " {

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

@test "${base}: vc_stats" {

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

@test "${base}: __vc_gitrepo - report a vendor/project repo ID-ish" {

  #run __vc_gitrepo
  #test_ok_empty || stdfail 1
  
  TODO  cleanup
  git remote add origin git@github.com:dotmpe/script-mpe.git
  run __vc_gitrepo
  test_ok_nonempty "dotmpe/script-mpe" || stdfail 2
}

# vim:ft=sh:
