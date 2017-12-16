#!/bin/sh

set -e

#grep -h '^\ *__[a-z_]*db__' *.py
grep -h '^__db__' *.py | cut -f 3 -d ' ' | sort -u

