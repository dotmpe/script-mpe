#!/usr/bin/env make.sh

version=0.0.4-dev # script-mpe


### User commands


rst_man_1__test="rst test? "
rst__test()
{
  test -z "$dry_run" || note " ** DRY-RUN ** " 0
  note "TODO box_run_cwd /home/.../bin Bats_test $@"
}


rst_man_1__date="Print date"
rst__date()
{
    echo 1
  test -z "$1" && {
    echo ":Date: $(date_microtime)"
  } || {
    test -e "$1" || err "no such file or path $1" 1
    test -z "$dry_run" || note " ** DRY-RUN ** " 0

    grep -q '^:Date:\s*$' "$1" && {
        note "Adding Date"
        xsed_rewrite 's/^:Date:.*$/:Date:\ '"$(date_microtime)"'/' "$1"
    } || {
        grep -q '^:Last-Modified:.*' "$1" && {
            note "Updateing last date"
            xsed_rewrite 's/^:Last-Modified:.*$/:Last-Modified:\ '"$(date_microtime)"'/' "$1"
        } || {
            note "Neither empty Date field nor a Last-Modified field present" 1
        }
    }
  }
}



### User help functions


rst_als____version=version
rst_als___V=version
rst_grp__version=ctx-main\ ctx-std

rst_als____help=help
rst_als___h=help
rst_grp__help=ctx-main\ ctx-std


rst_als___e=edit
rst_spc__edit='-e|edit'
rst__edit()
{
  $EDITOR $0 "$@"
}



### Main


MAKE-HERE
INIT_ENV="init-log 0 0-src 0-u_s 0-1-lib-sys 0-std ucache scriptpath box" \
INIT_LIB="\\$default_lib box src-htd"
main-local
subcmd_default=version
