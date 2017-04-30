#!/bin/sh


service_lib_load()
{
  test -n "$UCONFDIR" || UCONFDIR=$HOME/.conf/
  test -n "$HTD_SERVTAB" || export HTD_SERVTAB=$UCONFDIR/htd-services.tab
  test -n "$HTD_SERVD" || export HTD_SERVD=$UCONFDIR/htd/service/
}


htd_service_update_record()
{
  cd "$3" || error "service $1 dir missing: '$3'" 1
  test -e ".htd/services.yml" || {
    mkdir -vp $3/.htd
    echo 'services: []' > $3/.htd/services.yml
  }
  { cat <<EOM
{ "unid": "$1", "type": "$2", "pwd": "$3" }
EOM
  } | jsotk.py -I json --pretty append $3/.htd/services.yml services -
}

htd_service_exists()
{
  # TODO: test -e "$HTD_SERVD/$1.yml" && return
  cd "$3" || error "service $1 dir missing: '$3'" 1

  local serv_id=
  test -e ".htd/services.yml" && {
    serv_id=$( jsotk.py -qI yaml -O py objectpath \
      $3/.htd/services.yml '$.services[@.unid is "'$1'"].unid' || return 2)
  }
  test -n "$serv_id" && return
  case "$2" in
    htd )
      ;;
    systemd )
      ;;
    initd )
      ;;
    docker )
      ;;
    launchd )
      ;;
    pm2 )
      ;;
    vagrant )
      ;;
    vbox )
      ;;
  esac
  return 9
}

htd_service_status()
{
  cd "$3" || error "service $1 dir missing: '$3'" 1

  local serv_id=$1 serv_stat= serv_stat_msg=
  {
    local VAGRANT_CWD= VAGRANT_NAME=
    test -z "$HTD_SERV_ENV" ||
      eval $HTD_SERV_ENV
    case "$2" in
      htd )
          htd run status 2>/dev/null >&2 && serv_stat=0 || serv_stat=$?
        ;;
      systemd )
        ;;
      initd )
        ;;
      docker )
        ;;
      launchd )
        ;;
      pm2 )
          test -n "$PM_ID" || error "Need to track ID for pm2 type services" 1
        ;;
      vagrant )
          test -n "$VAGRANT_NAME" ||
            error "Need to track name for vagrant type services" 1
          vagrant_sh__status "$VAGRANT_NAME" 2>/dev/null >&2 && serv_stat=0 || serv_stat=$?
          export serv_stat_msg="$vgrnt_stat_msg"
        ;;
      vbox )
        ;;
    esac
  } || error "Error in $2 service $1 ($3)"
  test -n "$serv_stat" || {
    serv_stat=8
    serv_stat_msg="Not implemented"
  }
  export htd_serv_stat_msg=$serv_stat_msg

  { cat <<EOM
{ "status": $serv_stat, "status-message": "$serv_stat_msg" }
EOM
  } | jsotk.py -I json --pretty update-at $3/.htd/services.yml '$.services[@.unid is "'$1'"]' -

  return $serv_stat
}

