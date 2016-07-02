#!/bin/sh
esop_src="$_"

set -e



version=0.0.0+20150911-0659 # script-mpe


esop_man_1__version="Version info"
esop__version()
{
  echo "$(cat $scriptdir/.app-id)/$version"
}
esop_als__V=version


esop_run__run=f
esop__run()
{
  test -n "$1" || error "argument expected" 1
  case "$1" in

    '*' | bats-specs )
        case "$(whoami)" in
          travis )
            PATH=$PATH:/home/travis/usr/libexec/
            ;;
          * )
            PATH=$PATH:/usr/local/libexec/
            ;;
        esac
        count=0; specs=0
        for x in ./test/*-spec.bats
        do
          local s=$(bats-exec-test -c "$x" || error "Bats source not ok: cannot load $x" 1)
          incr specs $s
          incr count
        done
        test $count -gt 0 \
          && note "$specs specs, $count spec-files OK" \
          || { warn "No Bats specs found"; echo $1 >>$failed; }
      ;;

    '*' | bats )
        export $(hostname -s | tr 'A-Z.-' 'a-z__')_SKIP=1
        { ./test/*-spec.bats || echo $1>>$failed; } | bats-color.sh
        #for x in ./test/*-spec.bats;
        #do
        #  bats $x || echo $x >> $failed
        #done
        # ./test/*-spec.bats || { echo $1>>$failed; }
      ;;
  esac
  test ! -e $failed || return 1
}


esop_main()
{
  local \
      scriptname=esop \
      base="$(basename $0 ".sh")" \
      scriptdir="$(cd "$(dirname "$0")"; pwd -P)"
  case "$base" in
    $scriptname )
      esop_init || return $?
      run_subcmd "$@" || return $?
      ;;
    * )
      echo "$scriptname: not a frontend for $base"
      exit 1
      ;;
  esac
}

esop_init()
{
  export SCRIPTPATH=$scriptdir
  . $scriptdir/util.sh
  util_init
  . $scriptdir/main.lib.sh
  . $scriptdir/std.lib.sh
  . $scriptdir/str.lib.sh
  . $scriptdir/util.sh
  . $scriptdir/box.init.sh
  box_run_sh_test
  # -- esop box init sentinel --
}

esop_load()
{
  local __load_lib=1
  . $scriptdir/match.sh load-ext
  # -- esop box load sentinel --
}


case "$0" in "" ) ;; "-"* ) ;; * )
  test -z "$__load_lib" || set -- "load-ext"
  case "$1" in load-ext ) ;; * )
    esop_main "$@" || exit $?
  ;; esac
;; esac
