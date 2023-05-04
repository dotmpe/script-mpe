#!/bin/sh


#lfs_lib__load()
#{
#  true
#}

# List sha2
lfs_content_list()
{
  ( test -z "$1" || cd "$1"
  for _1 in */
  do
    for _2 in $_1/*/
    do
      for ckr in $_2/*
      do
          echo "$ckr" | tr -d '/'
      done
    done
  done
  )
}
