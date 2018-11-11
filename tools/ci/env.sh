# Boilerplate env for CI scripts
test -x "$(which gdate)" && gdate=gdate || gdate=date

start_time=$($gdate +"%s.%N")

test -n "$PS1" && _PS1=$PS1
PS1=$_PS1
test "$SHIPPABLE" = true &&
    export LOG=/root/src/bitbucket.org/dotmpe-personal/script-mpe/log.sh ||
    export LOG=$PWD/log.sh
{
  test "$SHIPPABLE" = true ||
  python -c 'import sys
if not hasattr(sys, "real_prefix"): sys.exit(1)'
} || {
  test -d ~/.pyvenv/htd || virtualenv ~/.pyvenv/htd
  . ~/.pyvenv/htd/bin/activate
}
. ./tools/sh/init.sh &&
lib_load std str sys shell build projectenv env-deps web
test -n "$BASH_SH" || error "Need to know shell dist" 1
test 0 -eq $BASH_SH && {
   export SCR_SYS_SH=sh || export SCR_SYS_SH=bash-sh
} || true

env_time=$($gdate +"%s.%N")
. ./tools/sh/env.sh

end_time=$($gdate +"%s.%N")
note "CI Env load time: $(echo "$end_time - $start_time"|bc) seconds"
note "Tools-Sh Env load time: $(echo "$end_time - $env_time"|bc) seconds"
