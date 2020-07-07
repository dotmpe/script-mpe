#!/usr/bin/env make.sh
# Created: 2016-03-28

version=0.0.4-dev # script-mpe


# Script subcmd's funcs and vars

# See $scriptname help to get started

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
        { ./test/*-spec.bats || echo $1>>$failed; } | script-bats.sh colorize
        #for x in ./test/*-spec.bats;
        #do
        #  bats $x || echo $x >> $failed
        #done
        # ./test/*-spec.bats || { echo $1>>$failed; }
      ;;

  esac
  test ! -e $failed || return 1
}


# Generic subcmd's

esop_man_1__help="Echo a combined usage and command list. With argument, seek all sections for that ID. "
esop_load__help=f
esop_spc__help='-h|help [ID]'
esop__help()
{
  test -z "$dry_run" || note " ** DRY-RUN ** " 0
  choice_global=1 std__help "$@"
  rm_failed || return
}
esop_als___h=help


esop_man_1__version="Version info"
esop__version()
{
  echo "script-mpe:$scriptname/$version"
}
esop_als___V=version
esop_als____version=version


esop__edit()
{
  $EDITOR $0 $(which $base.py) "$@"
}
esop_als___e=edit



### Main

MAKE-HERE
INIT_ENV="init-log 0 0-src dev init-log ucache scriptpath std box" \
INIT_LIB="str sys os std log stdio main argv shell box src logger-theme"

main-local
failed=

main-unload
  clean_failed || unload_ret=1 ; unset failed

main-epilogue
# Id: script-mpe/0.0.4-dev esop.sh
