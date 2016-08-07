#!/usr/bin/env bash


setup_clean_git()
{
  tmpd
  cd $tmpd
  git init
  touch .gitignore
  git add .
  git ci -m Init
}


