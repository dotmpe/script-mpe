#!/usr/bin/env bash


setup_clean_git()
{
  tmpd
  tmpd=$(cd $tmpd && pwd -P)
  cd $tmpd
  git init
  touch .gitignore
  git add .

  git config --get user.name || {
    warn "Adding GIT user"
    git config --global user.email "dev+travis@dotmpe.com"
    git config --global user.name "Travis"
  }
  git commit -m Init
}
