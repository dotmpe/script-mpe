#!/bin/sh
topics_src=$_

set -e



version=0.0.4-dev # script-mpe


# Script subcmd's funcs and vars

# See $scriptname help to get started

topics__stats()
{
  db_sa.py stats topic
}


topics__info()
{
  topic.py info
}


topics__list()
{
  topic.py list
}


topics__read_list()
{
  # [2017-04-17] experimental setup to read items into outline hierarchy
  export LIST_DB=$TOPIC_DB
  list.py read-list hier.txt @Topic
}



# Generic subcmd's

topics_man_1__help="Usage help. "
topics_spc__help="-h|help"
topics__help()
{
  test -z "$dry_run" || note " ** DRY-RUN ** " 0
  choice_global=1 std__help "$@"
}
topics_als___h=help


topics_man_1__version="Version info"
topics__version()
{
  echo "script-mpe:$scriptname/$version"
}
topics_als__V=version


topics__edit()
{
  $EDITOR $0 $(which $base.py) "$@"
}
topics_als___e=edit



### Main


topics_main()
{
  local
      scriptname=topics \
      base="$(basename "$0" ".sh")" \
      verbosity=5 \
    scriptpath="$(cd "$(dirname "$0")"; pwd -P)" \
    failed=

  topics_init || exit $?

  case "$base" in

    $scriptname )

        test -n "$1" || set -- list

        topics_lib || exit $?
        main_run_subcmd "$@" || exit $?
      ;;

    * )
        error "not a frontend for $base ($scriptname)" 1
      ;;

  esac
}

# Initial step to prepare for subcommand
topics_init()
{
  test -n "$scriptpath"
  . $scriptpath/tools/sh/init.sh
  #: "${sh_tools:="$scriptpath/tools/sh"}"
  #: "${ci_tools:="$scriptpath/tools/ci"}"
  #util_mode=ext . $scriptpath/tools/sh/util.sh
  lib_load match
  . $scriptpath/tools/sh/box.env.sh
  box_run_sh_test
  lib_load main meta box date doc table remote std
  # -- topics box init sentinel --
}

# Second step to prepare for subcommand
topics_lib()
{
  local __load_lib=1
  . $scriptpath/match.sh load-ext
  # -- topics box lib sentinel --
  set --
}


### Subcmd init, deinit

# Pre-exec: post subcmd-boostrap init
topics_load()
{
  export TOPIC_DB=postgres://localhost:5432
  # -- topics box lib sentinel --
  set --
}

# Post-exec: subcmd and script deinit
topics_unload()
{
  local unload_ret=0

  for x in $(try_value "${subcmd}" "" run | sed 's/./&\ /g')
  do case "$x" in
      f )
          clean_failed || unload_ret=1
        ;;
  esac; done

  unset subcmd subcmd_pref \
          topics_default def_subcmd func_exists func \
          failed topics_session_id

  return $unload_ret
}


# Main entry - bootstrap script if requested
# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )

  # Ignore 'load-ext' sub-command
  test "$1" != load-ext || __load_lib=1
  test -n "${__load_lib-}" || {
    #case "$SHELL" in
    #    */bin/bash ) set -o nounset ;;
    #    */bin/dash ) set -o nounset -o pipefail ;;
    #esac
    test -z "${DEBUG-}" || set -x
    topics_main "$@" || exit $?
  }
;; esac

# Id: script-mpe/0.0.4-dev topics.sh
