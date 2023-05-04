#!/usr/bin/env bash

ctx_github_lib__load ()
{
  lib_require web github
}

@Github.reportlines()
{
  echo "\$format index repositories @Github -- @Github.list"
}

@Github.list ()
{
  github_repos_list
}

#
