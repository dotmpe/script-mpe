#!/usr/bin/env bash


vc_setup_clean_git()
{
  tmpd
  tmpd=$(cd $tmpd && pwd -P)
  cd $tmpd
  vc_setup_git
}

vc_setup_git()
{
  git init
  touch .gitignore
  git add .

  git config --get user.name || {
    warn "Adding GIT user (updating global GIT config)"
    git config --global user.email "dev+travis@dotmpe.com"
    git config --global user.name "Travis"
  }
  git commit -m Init
  git tag -a -m "Root commit" root
}

vc_setup_submodule()
{
  test -n "$submodule" || set -- submodule
  tmpd
  smtmpd=$(cd $tmpd && pwd -P)
  cd $smtmpd
  vc_setup_git
  cd "$tmpd"
  git add submodule $smtmpd $1
}
