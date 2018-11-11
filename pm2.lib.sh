#!/bin/sh


pm2_json()
{
  test -n "$1" || set -- ~/htdocs/app "$2"
  #test -n "$2" || set -- "$1" ""
  test -z "$2" &&
      json=$1/pm2-apps.json ||
      json=$1/pm2-apps.$2.json
}

htd_pm2_list()
{
  test -n "$json" || pm2_json "$@"
  jq -r '.apps[] | .name' $json
}

htd_pm2_app_json()
{
  test -n "$json" || pm2_json "$@"
  printf -- "["
  jq '.apps[] | select(.name=="'"$1"'")' "$json"
  printf -- "]"
}

htd_pm2_start_if_stopped()
{
  test -n "$1" || error "pm2 start: name expected" 1
  local pid=$(pm2 pid "$1") name="$1" ; shift
  test -n "$pid" || {
    test -n "$json" || pm2_json "$@"
    htd_pm2_app_json "$name" | pm2 start - &&
        note "pm2 '$name' started" ||
        error "pm2 start $name: $?" 1
  }
}

htd_pm2_stop_if_running()
{
  test -n "$1" || error "pm2 stop: name expected" 1
  local pid=$(pm2 pid "$1") name="$1" ; shift
  test -z "$pid" || {
    pm2 -s delete "$name" &&
        note "pm2 '$name' stopped" || error "pm2 stop $name: $?" 1
  }
}
