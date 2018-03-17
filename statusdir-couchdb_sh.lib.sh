#!/bin/sh

set -e


couchdb_sh()
{
  test -n "$sd_be_timeout" || sd_be_timeout=3
  test -n "$ccurl_f" || ccurl_f=--connect-timeout\ $sd_be_timeout
  #test -n "$sd_be_maxtime" || sd_be_maxtime=15
  #test -n "$ccurl_f" || ccurl_f=--max-time\ 7\ --connect-timeout\ 3

  curl="curl -sf $ccurl_f"

  case "$1" in
    get )
        local json="$( $curl $COUCH_URL/$COUCH_DB/$2 )" || return
        test -n "$json" || return
        echo "$json" | jsotk -Opy path - $COUCH_SD_VKEY
      ;;
    set )
        local json_data='{"'$COUCH_SD_VKEY'": "'$4'"}'
        rev="$(eval echo $( $curl $COUCH_URL/$COUCH_DB/$2 | jq  ._rev))" || return
        test -n "$rev" &&
        {
          $curl -X PUT -S $COUCH_URL/$COUCH_DB/$2 \
            -H If-Match:$rev \
            -d "$json_data" || return $?
        } || {
          $curl -X PUT -S $COUCH_URL/$COUCH_DB/$2 \
            -d "$json_data" || return $?
        }
      ;;
    incr )
        eval "$( $curl $COUCH_URL/$COUCH_DB/$2 |
            jq -r '@sh "rev=\(._rev) v=\(.value)"' )" || return
        local json_data='{"'$COUCH_SD_VKEY'": "'$(( $v + 1 ))'"}'
        $curl -X PUT -S $COUCH_URL/$COUCH_DB/$2 \
          -H If-Match:$rev \
          -d "$json_data" >/dev/null || return $?
        expr $v + 1
      ;;
    decr )
        eval "$( $curl $COUCH_URL/$COUCH_DB/$2 |
            jq -r '@sh "rev=\(._rev) v=\(.value)"' )" || return
        local json_data='{"'$COUCH_SD_VKEY'": "'$(( $v - 1 ))'"}'
        echo $( $curl -X PUT -S $COUCH_URL/$COUCH_DB/$2 \
          -H If-Match:$rev \
          -d "$json_data" >/dev/null || return $?)
        expr $v - 1
      ;;
    del|delete )
        local rev=$( $curl $COUCH_URL/$COUCH_DB/$2 | jq  ._rev) || return $?

        $curl -X DELETE -S $COUCH_URL/$COUCH_DB/$2 -H If-Match:$rev ||
            return $?
      ;;
    ping )
        $curl -So/dev/null $COUCH_URL/$COUCH_DB || return
      ;;
    list ) error "TODO couchdb $@" 1
      ;;
    backend )
        echo couchdb $COUCH_URL $COUCH_DB
      ;;
    x|be|info )
        $curl -S $COUCH_URL || return
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
