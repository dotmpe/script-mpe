#!/bin/sh
# Created: 2016-01-24
gv_inc__source=$_


# Pre-run stage 2: parse argv
gv_parse_argv()
{
  req_vars parse_all_argv subcmd c verbosity xopts
  # Parse subcmd, opts. Continue after subcmd if <base>_argv__<subcmd> has value.
  while test $# -gt 0
  do
    #echo "1:$1 left:$#"
    # test for subcmd
    case "$1" in
        [a-z_]* )
          incr_c
          trueish "$parse_all_argv" && test -n "$subcmd" && {
            shift
            continue
          }
          subcmd=$1
          gv__load_subcmd
          trueish "$parse_all_argv" \
            || return 0
          shift
          continue
          ;;
    esac
    # test for opt
    case "$1" in
        -v )
          verbosity=$(( $verbosity + 1 ))
          incr_c
          shift;;
        --* )
          error "No long opts understood: $1" 1
          incr_c
          shift;;
        -- )
          incr_c
          shift
          note "More args: $@"
          return;;
        -* )
          #echo x-opt $1
          incr_c
          shift;;
    esac
  done
}

# Pre-run stage 2b: prepare for subcmd after it is parsed
gv__load_subcmd()
{
  test -n "$subcmd" || subcmd=$def_subcmd
  test -n "$subcmd" || error "no cmd or default" 1
  subcmd_func="$(try_local "$subcmd")"

  # Look for <base>_run__<subcmd> variable
  for x in $(try_value "${subcmd}" "" run | sed 's/./&\ /g')
  do case "$x" in

      a )
        # parse all of argv, continue after subcmd. Default is breaking at
        # subcmd.
        parse_all_argv=true
        ;;

      G )
        # check for Graph file/init graph= var before subcmd
        #graph="$(gv__bg print-graph-path)"
        graph=graphviz.gv
        test -e "$graph" || error "No graphviz file $graph" 1
        p="$(realpath $graph | sed 's/[^A-Za-z0-9_-]/-/g' | tr -s '_' '-')"
        sock=/tmp/gv-$p-serv.sock
        ;;

      f )
        # prepare pathname for subshell status return
        failed=/tmp/${base}-$subcmd.failed
        ;;

      b )
        # run metadata server in background for subcmd, and tear down after
        req_vars sock graph
        gv_bg_run
        ;;

    esac
  done
}

# Post-run: unset, cleanup
gv__unload()
{
  unset subcmd subcmd_pref \
          def_subcmd func_exists func
  test ! -e "$sock" || {
    gv_bg_teardown
  }
  test -z "$failed" -o ! -e "$failed" || {
    rm $failed
    unset failed
    return 1
  }
}


# Init Bg service
gv_bg_run()
{
  req_vars no_background sock
  test -n "$no_background" && {
    note "Forcing foreground/cleaning up background"
    test ! -e "$sock" \
      || gv__bg exit \
      || error "Exiting old" $?
  } || {
    test ! -e "$sock" || error "background service already running" 1
    gv__bg &
    while test ! -e $sock
    do note "Waiting for server.." ; sleep 1 ; done
    info "Backgrounded at $sock for $doc (PID $!)"
  }
}

# Close Bg service
gv_bg_teardown()
{
  test ! -e "$sock" || {
    gv__bg exit
    while test -e $sock
    do note "Waiting for background shutdown.." ; sleep 1 ; done
    info "Closed background service"
    test -z "$no_background" || warn "no-background on while sock existed"
  }
}

#
