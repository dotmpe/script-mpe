#!/usr/bin/env bash


setup_clean_git()
{
  local tmpd=/tmp/vc-bats-$(uuidgen)
  mkdir -vp $tmpd
  cd $tmpd
  git init
  touch .gitignore
  git add .
  git ci -m Init
}


