# Boilerplate env for CI scripts

echo "0.1"
. ./tools/sh/init.sh
echo "0.2"
lib_load std str sys bash projectenv env-deps
echo "0.3"
test -n "$BASH_SH" || error "Need to know shell dist" 1
test 0 -eq $BASH_SH && {
   export SCR_SYS_SH=sh || export SCR_SYS_SH=bash-sh
}
echo "0.4"
. ./tools/sh/env.sh
echo "0.5"
