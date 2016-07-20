#!/usr/bin/env bats

load helper
load vc
base=vc.sh
init


setup() {
  . ./$base load-ext
  . ./util.sh load-ext
  lib_load os sys str std match
  setup_clean_git
}

@test ". $bin __vc_gitdir - reports GIT dir in GIT checkout" {

  tmpd=$(pwd -P)

  run __vc_gitdir
  test $status -eq 0 \
    || fail "Status: $status"
  test "${lines[@]}" = "$tmpd/.git" \
    || fail "Lines: ${lines[@]} ($tmpd)"

  mkdir -p sub-1/sub-1.1
  cd sub-1/sub-1.1
  run __vc_gitdir
  test $status -eq 0
  test "${lines[@]}" = "$tmpd/.git" \
    || fail "Lines 2: ${lines[@]} ($tmpd)"
}

@test ". $bin __vc_git_flags - " {

  run __vc_git_flags
  test $status -eq 0 \
    || fail "Status $status"
  test "$(echo ${lines[@]})" = "(master)" \
    || fail "${lines[@]}"

  vc.sh ps1

  mkdir -vp sub-1/sub-1.1
  cd sub-1/sub-1.1
  run __vc_git_flags
  test $status -eq 0
  test "$(echo ${lines[@]})" = "(master)" \
    || fail "${lines[@]}"
}

@test ". $bin __vc_status - status reports line for e.g. PS1 use" {

  shopt -s extglob

  run __vc_status
  test $status -eq 0
  fnmatch "$tmpd \[git:master +([0-9a-f])...\]" "${lines[*]}" \
    || fail "${lines[@]}"

  mkdir -vp sub-1/sub-1.1
  cd sub-1/sub-1.1
  run __vc_status
  test $status -eq 0
  fnmatch "$tmpd \[git:master +([0-9a-f])...\]/sub-1/sub-1.1" "${lines[*]}" \
    || fail "${lines[@]}"

  shopt -u extglob
}

@test ". $bin __vc_gitrepo - report a vendor/project repo ID-ish" {

  run __vc_gitrepo
  test $status -ne 0 \
    || fail "${status}"
  
  git remote add origin git@github.com:dotmpe/script-mpe.git
  run __vc_gitrepo
  test $status -eq 0 \
    || fail "__vc_gitrepo ret ${status}, lines: ${lines[@]}"
  test "${lines[@]}" = "dotmpe/script-mpe" \
    || fail "${lines[@]}"
}

# vim:ft=sh:
