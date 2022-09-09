#!/usr/bin/env make.sh
# Created: 2015-12-14

version=0.0.4-dev # script-mpe


### Sub-commands


gv__edit()
{
  $EDITOR $0 ~/bin/graphviz.inc.sh $(which graphviz.py) "$@"
}

gv_flags__meta=G
# Defer to python
gv__meta()
{
  test -n "$1" || set -- "--background"
  graphviz.py --file $graph --address $sock "$@" || return $?
}

gv_flags__bg=G
# Defer and wait
gv__bg()
{
  note "Starting Bg service"
  gv__meta "$@" &
  sock="$(gv__meta print-socket-name)"

  while test ! -e "$sock"
  do note "Waiting for Bg at $sock"; sleep 2;
  done

  std_info "Backgrounded"
}

gv_flags__info=G #b
# Test argv
gv__info()
{
  gv__meta print-info
}


# ----


gv__usage()
{
  echo 'Usage: '
  echo "  $scriptname.sh <cmd> [<args>..]"
}

gv_grp__version="ctx-main ctx-std"
gv_als____version=version
gv_als___V=version


gv__help()
{
  gv__usage
  echo 'Functions: '
  echo '  usage                            print short usage.'
  echo '  help                             print this help listing.'
  echo '  bg                               background service'
  echo '  edit                             edit main script'
  echo '  meta                             call backend service with query'
  echo '  info                             query for info'
  test -z "${1-}" || std__help "$@"
}
gv_als___h=help
gv_als____help=help


### Main

MAKE-HERE
INIT_ENV="init-log 0 0-src 0-u_s dev ucache scriptpath std box" \
INIT_LIB="\\$default_lib logger-theme graphviz date"

main-bases
graphviz gv main std

main-local
failed= box_prefix=gv

main-load

  local tdy="$(try_value "${subcmd}" "" today)"

  test -z "$tdy" || {
    today=$(statusdir.sh file $tdy)
    tdate=$(date +%y%m%d0000)
    test -n "$tdate" || error "formatting date" 1
    touch -t $tdate $today
  }

  # box_lib $script $box_prefix

  # gv_parse_argv "$@" || {
  #   error "parse-argv" $?
  # }

  # shift $c
  test -n "$subcmd_func" || {
    error "subcmd-func required" $?
  }

main-load-flags
    f ) # failed: set/cleanup failed varname
        export failed=$(setup_tmpf .failed)
      ;;
    l ) sh_include subcommand-libs || return ;;
    * ) error "No load flag <$x>" 3 ;;

main-unload-flags
    f ) clean_failed || unload_ret=1 ;;
    l ) ;;
    * ) error "No unload flag <$x>" 3 ;;

main-epilogue
# Id: script-mpe/0.0.4-dev topics.sh
