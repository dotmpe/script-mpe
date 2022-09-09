#!/usr/bin/env make.sh

version=0.0.4-dev # script-mpe

set -eu

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

topics_als____version=version
topics_als___V=version
topics_grp__version=ctx-main\ ctx-std

topics_als____help=help
topics_als___h=help
topics_grp__help=ctx-main\ ctx-std


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

main-load
  export TOPIC_DB=postgres://localhost:5432

main-unload
  clean_failed || unload_ret=1 ; unset failed

main-epilogue
# Id: script-mpe/0.0.4-dev topics.sh
