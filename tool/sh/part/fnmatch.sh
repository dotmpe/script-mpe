#!/bin/sh

fnmatch() { case "$2" in $1 ) return ;; * ) return 1 ;; esac; }

# Sync: U-S:
