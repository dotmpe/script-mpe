#!/bin/sh

htd_src_init()
{
  test -d "/src/$1/$2/$3" && return
  url="$(htd__gitremote url $1 $3)" || return
  mkdir -vp "/src/$1/$2/"
  git clone $url "/src/$1/$2/$3"
}
