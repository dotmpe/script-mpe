#
# Copyright 2008-2026 B. van Berkum <dev@dotmpe.com>
#
# Distributed under terms of the MIT license.
#if LANG == bash
: "${DEBUG:=0}"
: "${QUIET:=0}"
! ((DEBUG)) || {
  shopt -s extdebug
  PS4='\[\033[0m\]${BASH_SOURCE:+\[\033[34m\]$BASH_SOURCE\[\033[36m\]:\[\033[32m\]${LINENO}} \[\033[33m\]+\[\033[0m\] '
  ((QUIET)) ||
    >&2 echo "$$$-\$ $0 ${*@Q}"
}
#elif LANG == txt
There is no debug for plain text.
Try really, really hard to read whats going on.
#else
#error unsupported shell LANG
#endif
# Id: debug.sh.h                                vim:set ft=bash sw=2 sts=2 et:
