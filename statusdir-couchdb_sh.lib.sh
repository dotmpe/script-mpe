#!/bin/sh

set -e


couchdb_sh()
{
  case "$1" in
    get )
        local json="$( curl -sf $COUCH_URL/$COUCH_DB/$2 )" || return
        test -n "$json" || return
        echo "$json" | jsotk -Opy path - $COUCH_SD_VKEY
      ;;
    set )
        local json_data='{"'$COUCH_SD_VKEY'": "'$4'"}'
        rev="$(eval echo $(curl -sf $COUCH_URL/$COUCH_DB/$2 | jq  ._rev))" || return
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
        eval "$( curl -sf $COUCH_URL/$COUCH_DB/$2 |
            jq -r '@sh "rev=\(._rev) v=\(.value)"' )" || return
        local json_data='{"'$COUCH_SD_VKEY'": "'$(( $v + 1 ))'"}'
        curl -X PUT -sSf $COUCH_URL/$COUCH_DB/$2 \
          -H If-Match:$rev \
          -d "$json_data" >/dev/null || return $?
        expr $v + 1
      ;;
    decr )
        eval "$( curl -sf $COUCH_URL/$COUCH_DB/$2 |
            jq -r '@sh "rev=\(._rev) v=\(.value)"' )" || return
        local json_data='{"'$COUCH_SD_VKEY'": "'$(( $v - 1 ))'"}'
        echo $(curl -X PUT -sSf $COUCH_URL/$COUCH_DB/$2 \
          -H If-Match:$rev \
          -d "$json_data" >/dev/null || return $?)
        expr $v - 1
      ;;
    del|delete )
        local rev=$(curl -sf $COUCH_URL/$COUCH_DB/$2 | jq  ._rev) || return $?

        curl -X DELETE -sSf $COUCH_URL/$COUCH_DB/$2 -H If-Match:$rev ||
            return $?
      ;;
    ping )
        curl -sSf $COUCH_URL/$COUCH_DB || return
      ;;
    list ) error "TODO couchdb $@" 1
      ;;
    backend )
        echo couchdb $COUCH_URL $COUCH_DB
      ;;
    x|be|info )
        curl -sSf $COUCH_URL || return
      ;;
    * ) echo "Error $0: $1 ($2)"; exit 101 ;;
  esac
}


statusdir_couchdb_sh_lib_load()
{
  test -n "$COUCH_DB" || error "Couch-DB expected" 1
  test -n "$COUCH_URL" || export COUCH_URL=http://localhost:5984
  test -n "$COUCH_SD_VKEY" || export COUCH_SD_VKEY=value
}
