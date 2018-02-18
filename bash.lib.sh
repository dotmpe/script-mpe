#!/bin/sh

bash_lib_load()
{
  # Try to figure out what we are.. and how to keep it Bourne Shell compatible
  test "$(basename "$SHELL")" = "bash" && {
    export BASH_SH=1
  } || {
    export BASH_SH=0
  }

  type typeset 2>&1 >/dev/null && {
    test 1 -eq $BASH_SH || {
      # Not spend much time outside GNU, busybox or BSD 'sh' & Bash.
      echo "Found typeset cmd, expected Bash" >&2
      return 1
    }
  }

}
