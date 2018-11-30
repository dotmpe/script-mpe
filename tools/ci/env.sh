# Boilerplate env for CI scripts
test -x "$(which gdate)" && gdate=gdate || gdate=date

start_time=$($gdate +"%s.%N")

test -n "$PS1" && _PS1=$PS1
PS1=$_PS1
test "$SHIPPABLE" = true &&
    export LOG=/root/src/bitbucket.org/dotmpe-personal/script-mpe/log.sh ||
    export LOG=$PWD/log.sh
echo "Testing for Py venv" >&2
{
  test "$SHIPPABLE" = true || {
    ( python -c 'import sys;
if not hasattr(sys, "real_prefix"): sys.exit(1)' ) || false
  }
} || {
  test -d ~/.pyvenv/htd || virtualenv ~/.pyvenv/htd
  . ~/.pyvenv/htd/bin/activate || {
    echo "Error in Py venv setup ($?)" >&2
    exit 1
  }
}
echo "Loading shell util" >&2
__load_mode=boot . ./util.sh || {
    echo "Error loading initial sh mods ($?)" >&2
    exit 1
  }
info "std env loaded"
shell_init || error "Failure in shell-init" 1
test -n "$IS_BASH" || error "Need to know shell dist" 1
#. ./tools/sh/init.sh &&
lib_load build projectenv env-deps web
test 0 -eq $IS_BASH_SH && {
   export SCR_SYS_SH=sh || export SCR_SYS_SH=bash-sh
} || true

env_time=$($gdate +"%s.%N")
. ./tools/sh/env.sh

end_time=$($gdate +"%s.%N")
note "CI Env load time: $(echo "$end_time - $start_time"|bc) seconds"
note "Tools-Sh Env load time: $(echo "$end_time - $env_time"|bc) seconds"
