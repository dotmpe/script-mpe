#!/bin/bash
# system tests

NUM="$1"
PREFIX="/tmp/tests/script.mpe/system_$NUM"

if test -z "$1"; then
    while $0 $((++i)); do true; done
    exit 0
fi


function check
{
  printf " * %-59s %-6s\n" "$1" "$2"
}

function check_exists
{
  if test -e $PREFIX.$2
  then
    check "$1" PASSED
  else
    check "$1" FAILED
  fi
}

function check_compare
{
    if diff -bq "$1" "$2" > /dev/null
    then
      check "$3" PASSED
    else
      check "$3" FAILED
      diff  "$1" "$2"
    fi
}

function check_run # cmd outname
{
    if $1 > $PREFIX$2.txt 2> $PREFIX$2-error.log
    then
        if test -z "$2"
        then
          if test -z "$3"
          then
              check "\$ $1" PASSED
          else
              check "$3" PASSED
          fi
        else
            check "Created $PREFIX$2{-error.log,.txt}"
        fi
        return
    else
        check "Run '$1'" FAILED
        return 1
    fi
}

function check_out # cmd name
{
    if check_run "$1" .$2
    then
        [ -n "$3" ] && { msg="$3"; } || { msg="'$1' output is as expected"; }
        check_compare $PREFIX.$2.txt "test/var/$2.txt" "$msg"
    fi
}

function coveragereport
{
    [ -z "$COVERAGE_PROCESS_START" ] && return
    echo Generating coverage report
    coverage combine
    coverage html
}

function line
{
  printf -- "$CHAR%.0s" {1..70} 
  printf "\n"
}

function test_start # descr
{
  CHAR="-" line
#  CHAR='=' line
  printf "%7s: %-63s\n" "Test $NUM" "$*"
#  CHAR="-" line
}

function test_end
{
  set --
#  CHAR='=' line
}

[ -e $(dirname $PREFIX) ] || { mkdir -p $(dirname $PREFIX); }

set -m
case $1 in

  1)
    test_start libcmd.SimpleCommand and StackedCommand
    check_out "python libcmd.py -h" libcmd_help
    check_out "python libcmd_stacked.py -h" libcmd_stacked_help
    test_end
    ;;

  2)
    test_start htdocs
    check_out "htdocs.py -h" htdocs_help
    test_end
    ;;

  3)
    test_start rsr
    check_out "rsr.py -h" rsr_help
    check_run "rsr.py --list" .all-nodes
    check_run "rsr.py --assert group/test-node --commit"
    check_run "rsr.py --assert group/group2/ --commit"
    check_run "rsr.py --list" .all-nodes.new
    check_out "rsr.py --nodes group test-node group2" rsr_nodes
    check_run "rsr.py --remove group --commit"
    check_run "rsr.py --remove group2 --commit"
    check_run "rsr.py --remove test-node --commit"
    check_run "rsr.py --list" .all-nodes.2
    check_compare $PREFIX.all-nodes.txt $PREFIX.all-nodes.2.txt "Node list is as expected"
    test_end
    ;;

  4)
    test_start mimereg
    check_out "mimereg -h" mimereg_help
    test_end
    ;;

  5)
    test_start myCalendar
    check_run "python myCalendar.py"
    check_run "myCalendar.py ." 
    check_out "myCalendar.py -h" myCalendar_help
    test_end
    ;;

  6)
    test_start mkDoc
    check_run "python mkdocs.py"
    test_end
    ;;

  7)
    test_start Radical
    check_run "radical.py ."
    test_end
    ;;

  8)
    test_start cmdline
    check_run "cmdline.py" 
    SRC1=$PREFIX.source1
    mkdir -p $SRC1/foo/bar
    touch $SRC1/foo/bar/baz-1
    SRC2=$PREFIX.source2
    mkdir -p $SRC2/foo/bar
    touch $SRC2/foo/bar/baz-2
    cmdline.py --symlink-tree $PREFIX.target/ $SRC1 $SRC2
    #mkdir -p $PREFIX.source3/
    #touch $PREFIX.source3/foo
    test_end
    ;;

#  )
#    coveragereport
#    ;;

  *)
    exit 1
    ;;

esac

exit 0
# vim:sw=2:ts=2:et:
