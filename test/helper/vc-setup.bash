#!/usr/bin/env bash


vc_setup_clean_git()
{
  tmpd
  tmpd=$(cd $tmpd && pwd -P)
  cd $tmpd && vc_setup_for_git_commit && vc_setup_git
}

vc_setup_for_git_commit()
{
  git config --get user.name >/dev/null || {
    warn "Adding GIT user (updating global GIT config)"
    git config --global user.email "dev+travis@dotmpe.com"
    git config --global user.name "Travis"
  }
}

vc_setup_git()
{
  git init -q && touch .gitignore && git add . && git commit -q -m Init &&
  git tag -a -m "Root commit" root
}

vc_setup_submodule()
{
  local gitdir=$PWD
  test $gitdir/.git || return
  test -n "$1" || set -- submodule
  tmpd $1 && smtmpd=$(cd $tmpd && pwd -P) &&
  cd $smtmpd && vc_setup_git &&
  cd "$gitdir" && git submodule -q add $smtmpd $1
}
