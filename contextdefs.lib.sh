#!/bin/sh

contextdefs_cmd_seq_all ()
{
  local f=$1 h=$2 ; shift 2
  eval "$(cat <<EOM

$f ()
{
  $( test $# -eq 0 || printf 'test -n "${1-}" || set -- %s' "$1" )
  # XXX: fnmatch "* -- *" " \$* " || set -- "\$@" --
  func_exists=\${func_exists-0} first_only=\${first_only-0} context_cmd_seq $h "\$@"
}

EOM
  )"
}

#
