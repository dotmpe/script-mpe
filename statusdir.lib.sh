#!/bin/sh

statusdir_lib_load()
{
  test -n "$STATUSDIR_ROOT" || STATUSDIR_ROOT=$HOME/.statusdir
}

statusdir_lib_init()
{
  statusdir_check
}

statusdir_check()
{
  test -e "$STATUSDIR_ROOT/logs" || return
  test -e "$STATUSDIR_ROOT/index" || return
  test -e "$STATUSDIR_ROOT/tree" || return
}
statusdir_init()
{
  test -e "$STATUSDIR_ROOT/logs" || mkdir -p "$STATUSDIR_ROOT/logs"
  test -e "$STATUSDIR_ROOT/index" || mkdir -p "$STATUSDIR_ROOT/index"
  test -e "$STATUSDIR_ROOT/tree" || mkdir -p "$STATUSDIR_ROOT/tree"
}
