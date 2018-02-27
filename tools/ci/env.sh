# Boilerplate env for CI scripts
export DEBUG=1
. ./tools/sh/init.sh
lib_load std str sys bash projectenv env-deps
test -n "$BASH_SH" || error "Need to know shell dist" 1
test 0 -eq $BASH_SH && {
   export SCR_SYS_SH=sh || export SCR_SYS_SH=bash-sh
}
echo "shopts: '$shopts'"
echo "0.4"
. ./tools/sh/env.sh
echo "0.5"
