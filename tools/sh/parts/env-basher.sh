#!/bin/sh

case "$PATH" in
  *"$HOME/.basher/"* ) ;;
  * ) export PATH=$HOME/.basher/bin:$HOME/.basher/cellar/bin:$PATH ;;
esac
