#!/usr/bin/env make.sh

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

MAKE-HERE
INIT_ENV="init-log 0 0-src 0-u_s dev 0-std ucache scriptpath std box"
INIT_LIB="os sys str log shell match main meta src box date doc table remote std stdio"

main-local
failed=

main-lib
  local __load_lib=1
  INIT_LOG=$LOG lib_init || return

main-load
  export TOPIC_DB=postgres://localhost:5432

main-unload
  clean_failed || unload_ret=1 ; unset failed

main-epilogue
# Id: script-mpe/0.0.4-dev topics.sh
