#!/bin/sh

htd_man_1__eval='Inline eval
'
htd_eval__help ()
{
  echo "$htd_man_1__eval"
}

htd__eval()
{
  fnmatch "*A*" "$htd_flags__eval" && set -- $(cat "$arguments")
  test $# -gt 0 || set -- "for x in \${!htd_*__eval*};do echo \$x: \${!x}; done"
  eval "$*"
}

true "${htd_flags__eval:="iAOlq"}"
true "${htd_libs__eval:="date"}"

#
