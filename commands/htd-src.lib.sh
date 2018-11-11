#!/bin/sh

# Created checkout at vendored path
htd_src_init() # domain ns name
{
  test -d "/src/$1/$2/$3" && return
  url="$(htd__gitremote url $1 $3)" || return $?
  test -n "$url" || return $?
  mkdir -vp "/src/$1/$2/"
  git clone $url "/src/$1/$2/$3"
}
