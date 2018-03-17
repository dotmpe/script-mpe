#!/bin/sh
# Created: 2016-03-28
esop__source="$_"

set -e



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
  test $verbosity -gt 4 || export verbosity=4
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
#esop_als___V=version
#esop_als____version=version


esop__edit()
{
  $EDITOR $0 $(which $base.py) "$@"
}
esop_als___e=edit



# Script main functions

esop_main()
{
  local \
      scriptname=esop \
      base="$(basename $0 ".sh")" \
      scriptpath="$(cd "$(dirname "$0")"; pwd -P)"
      failed=

  debug esop-main
  case "$base" in
    $scriptname )
      debug esop-init
      esop_init || return $?
      debug esop-run-subcmd
      run_subcmd "$@" || return $?
      ;;
    * )
        echo "$scriptname: not a frontend for $base" >&2
        exit 1
      ;;
  esac
}

# FIXME: Pre-bootstrap init
esop_init()
{
  export LOG=/srv/project-local/mkdoc/usr/share/mkdoc/Core/log.sh
  export SCRIPTPATH=$scriptpath
  . $scriptpath/util.sh load-ext
  lib_load
  . $scriptpath/tools/sh/box.env.sh
  lib_load main
  box_run_sh_test
  # -- esop box init sentinel --
}

# FIXME
esop_lib()
{
  debug esop-lib
  # -- box box lib sentinel --
  set --
}


# Pre-exec: post subcmd-boostrap init
esop_load()
{
  # -- esop box load sentinel --
  set --
}

# Post-exec: subcmd and script deinit
tasks_unload()
{
  local unload_ret=0

  #for x in $(try_value "${subcmd}" "" run | sed 's/./&\ /g')
  #do case "$x" in
  # ....
  #esac; done

  clean_failed || unload_ret=$?

  unset subcmd subcmd_pref \
          def_subcmd func_exists func \
          failed

  return $unload_ret
}


# Main entry - bootstrap script if requested
# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )

  # Ignore 'load-ext' sub-command
  case "$1" in load-ext ) ;;
    * )
      esop_main "$@" ;;

  esac ;;
esac

# Id: script-mpe/0.0.4-dev esop.sh
