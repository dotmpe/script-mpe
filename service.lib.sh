#!/bin/sh


service_lib_load()
{
  test -n "$UCONF" || UCONF=$HOME/.conf/
  test -n "$HTD_SERVTAB" || export HTD_SERVTAB=$UCONF/htd-services.tab
  #test -n "$HTD_SERVD" || export HTD_SERVD=$UCONF/htd/service/
}

# Binds to local working dir
htd_service_env_req() # Dir Type SId
{
  test -s "$HTD_SERVTAB" ||
    error "Htd-SrvTab table required" 1
  test -n "$1" || set -- "." "$2" "$3"
  test -d "$1" || error "service $3 dir missing: <$1>" 1
  test -e "$1/.htd/services.yml" ||
    error "Htd services file required <$1>" 1
  # TODO: test -e "$HTD_SERVD/$1.yml" && return
  test -n "$3" || return
  export serv_id=$( jsotk.py -qI yaml -O py objectpath \
    $1/.htd/services.yml '$.services[@.unid is "'$3'"].unid' || return 2)
  test -n "$serv_id" ||
    error "Missing $2 service '$3' <$1>" 1
}

htd_service_exists() # SId Type Dir
{
  htd_service_env_req "$3" "$2" "$1" || return
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
  grep -q "^$1" "$HTD_SERVTAB" || return
  return 0
}

htd_service_record()
{
  grep "^$1\>\ " "$HTD_SERVTAB"
}

htd_service_attr()
{
  test -n "$cutf" -a -s "$cutf" || fixed_table_cuthd "$HTD_SERVTAB"
  arg="$(grep "^$2" $cutf | awk '{print $2}')"
  htd_service_record "$1" | cut $arg
}

htd_service_update_record() # SId Type Dir
{
  test -e "$3/.htd/services.yml" || {
    mkdir -vp $3/.htd
    echo 'services: []' > $3/.htd/services.yml
  }
  { cat <<EOM
{ "unid": "$1", "type": "$2", "pwd": "$3" }
EOM
  } | jsotk.py -I json --pretty append $3/.htd/services.yml services -
}

htd_service_status()
{
  htd_service_env_req "$3" "$2" "$1" || return

  local serv_id=$1 serv_stat= serv_stat_msg=
  {
    local VAGRANT_CWD= VAGRANT_NAME= pwd=$PWD
    cd "$3"
    test -z "$HTD_SERV_ENV" || eval $HTD_SERV_ENV
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
    cd "$pwd"
  } || error "Error in $2 service $1 ($3)"
  test -n "$serv_stat" || {
    serv_stat=8
    serv_stat_msg="Not implemented"
  }
  export htd_serv_stat_msg=$serv_stat_msg

  return $serv_stat
}

htd_service_status_info() # Type Code
{
  case "$1" in vagrant ) ;; esac
  case "$2" in
    2 ) echo not created ;;
    3 ) echo saved ;;
    8 ) echo Not implemented ;;
  esac
}

htd_service_metadata_update()
{
  { cat <<EOM
{ "status": $serv_stat, "status-message": "$serv_stat_msg" }
EOM
  } | jsotk.py -I json --pretty update-at $3/.htd/services.yml '$.services[@.unid is "'$1'"]' -
}

