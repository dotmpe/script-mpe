#!/bin/sh

bash_lib_load()
{
  SH_NAME="$(basename "$SHELL")"

  # Try to figure out what we are.. and how to keep it Bourne Shell compatible
  test "$SH_NAME" = "bash" && export BASH_SH=1 || export BASH_SH=0
  test "$SH_NAME" = "zsh" && export Z_SH=1 || export Z_SH=0
  test "$SH_NAME" = "dash" && export DASH_SH=1 || export DASH_SH=0

  type typeset 2>&1 >/dev/null && {
    test 1 -eq $Z_SH -o 1 -eq $BASH_SH || {
      # Not spend much time outside GNU, busybox or BSD 'sh' & Bash.
      echo "Found typeset cmd, expected Bash ($SH_NAME)" >&2
      return 1
    }
  } || true
}
