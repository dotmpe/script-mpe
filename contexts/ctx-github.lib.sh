#!/usr/bin/env bash

ctx_github_lib_load ()
{
  lib_require web github
}

@Github.reportlines()
{
  echo "index repositories @Github -- @Github.list"
}

@Github.list ()
{
  github_repos_list
}

#
