# Boilerplate env for CI scripts
test -n "$PS1" && _PS1=$PS1
test -d ~/.pyvenv/htd || virtualenv ~/.pyvenv/htd
source ~/.pyvenv/htd/bin/activate
PS1=$_PS1
. ./tools/sh/init.sh
lib_load std str sys bash build projectenv env-deps web
test -n "$BASH_SH" || error "Need to know shell dist" 1
test 0 -eq $BASH_SH && {
   export SCR_SYS_SH=sh || export SCR_SYS_SH=bash-sh
} || true
. ./tools/sh/env.sh
