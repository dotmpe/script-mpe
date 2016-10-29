#!/bin/sh
c_rst__source="$_ $0 $@"

set -e

version=0.0.2-dev # script-mpe


### User commands


c_rst_man_1__test="rst test? "
c_rst__test()
{
  test -z "$dry_run" || note " ** DRY-RUN ** " 0
  note "TODO box_run_cwd /home/.../bin Bats_test $@"
}


c_rst_man_1__date="Print date"
c_rst__date()
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


c_rst_als___h=help
c_rst_spc__help='-h|help [ID]'
c_rst__help()
{
  std__help rst "$@"
}


c_rst_als___e=edit
c_rst_spc__edit='-e|edit'
c_rst__edit()
{
  $EDITOR $0 "$@"
}


c_rst_man_1__version="Version info"
c_rst__version()
{
  echo "box-rst/$version"
}
c_rst_als___V=version



### Main


rst_main()
{
  local scriptdir="$(cd "$(dirname "$0")"; pwd -P)"
  rst_init || return 0
  local scriptname=rst base=$(basename $0 .sh) dirname=$(dirname $0)
  case "$base" in $scriptname )
      local subcmd_func_pref=c_${base} verbosity=5 c_rst_default=version
      rst_lib
      run_subcmd "$@" ;;
  esac
}

rst_init()
{
  test -z "$BOX_INIT" || return 1
  export SCRIPTPATH=$scriptdir
  . $scriptdir/util.sh
  util_init
  . $scriptdir/box.init.sh
  . $scriptdir/box.lib.sh
  box_run_sh_test
  . $scriptdir/main.lib.sh
  . $scriptdir/main.init.sh
  # -- rst box init sentinel --
}

rst_lib()
{
  # -- rst box lib sentinel --
  set --
}

rst_load()
{
  # -- rst box load sentinel --
  set --
}

# Use hyphen to ignore source exec in login shell
if [ -n "$0" ] && [ $0 != "-bash" ]; then
  rst_main "$@"
fi


