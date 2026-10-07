#!/bin/sh


linux_wherefrom ()
{
  xattr -p user.xdg.origin.url "$1"
}

#
