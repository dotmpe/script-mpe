#!/bin/sh

set -e


sd_be_name=couchdb_sh

couchdb_sh()
{
  case "$1" in

    get )
        {
          curl -sSf $COUCH_URL/$COUCH_DB/$2 |
            jsotk path - $COUCH_SD_VKEY
        } || return $?
      ;;
    set )
        echo "$COUCH_URL/$COUCH_DB/$2"
        {
          curl -X PUT -sSf $COUCH_URL/$COUCH_DB/$2 \
            -d '{"'$COUCH_SD_VKEY'": "'$4'"}'
        } || return $?
      ;;
    incr )
        error TODO 1
      ;;
    del )
        error TODO 1
      ;;
    ping )
        error TODO 1
      ;;
    list )
        error TODO 1
      ;;
    x|be|info )
        curl -sSf $COUCH_URL || return
      ;;
    * )
        echo "Error $0: $1 ($2)"
        exit 101
      ;;
  esac
}


statusdir_couchdb_sh_lib_load()
{
  test -n "$COUCH_DB" || error "Couch-DB expected" 1
  test -n "$COUCH_URL" || export COUCH_URL=http://localhost:5984
  test -n "$COUCH_SD_VKEY" || export COUCH_SD_VKEY=value
}

