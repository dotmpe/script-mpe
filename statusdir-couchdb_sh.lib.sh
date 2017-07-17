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
        test -n "$json_data" || json_data='{"'$COUCH_SD_VKEY'": "'$4'"}'
        rev=$(curl -sSf $COUCH_URL/$COUCH_DB/$2 | jq  ._rev || printf "")
        test -n "$rev" &&
        {
          curl -X PUT -sSf $COUCH_URL/$COUCH_DB/$2 \
            -H If-Match:$rev \
            -d "$json_data" || return $?
        } || {
          curl -X PUT -sSf $COUCH_URL/$COUCH_DB/$2 \
            -d "$json_data" || return $?
        }
      ;;
    incr )
        error TODO 1
      ;;
    del|delete )
        rev=$(curl -sSf $COUCH_URL/$COUCH_DB/$2 | jq  ._rev)
        test -z "$rev" ||
        curl -X DELETE -sSf $COUCH_URL/$COUCH_DB/$2 -H If-Match:$rev || return $?
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

