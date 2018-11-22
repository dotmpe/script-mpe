#!/bin/sh

statusdir_lib_load()
{
  test -n "$STATUSDIR_ROOT" || STATUSDIR_ROOT=$HOME/.statusdir
}
