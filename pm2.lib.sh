#!/bin/sh


pm2_lib_load()
{
  true
}

pm2_json()
{
  test -n "$1" || set -- ~/htdocs "$2"
  #test -n "$2" || set -- "$1" ""
  test -z "$2" &&
      json=$1/pm2-apps.json ||
      json=$1/pm2-apps.$2.json
}

htd_pm2_list()
{
  pm2_json "$@"
  jq -r '.apps[] | .name' $json
}

htd_pm2_start_if_stopped()
{
  test -n "$1" || error "pm2 start: name expected" 1
  local pid=$(pm2 pid "$1") name="$1" ; shift
  test -n "$pid" || {
    pm2_json "$@"
    pm2 -s start "$json" || error "pm2 start $name: $?" 1
  }
}

htd_pm2_stop_if_running()
{
  test -n "$1" || error "pm2 stop: name expected" 1
  local pid=$(pm2 pid "$1") name="$1" ; shift
  test -z "$pid" || {
    pm2 -s kill "$name" || error "pm2 stop $name: $?" 1
  }
}
