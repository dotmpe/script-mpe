#!/bin/sh


# Set default pm2-apps.json file
pm2_json()
{
  test -n "$1" || set -- ~/htdocs/app "$2"
  #test -n "$2" || set -- "$1" ""
  test -z "$2" &&
      json=$1/pm2-apps.json ||
      json=$1/pm2-apps.$2.json
}

# Show running servers, use default pm2-apps.json file if not set
htd_pm2_list() #
{
  test -n "$json" || pm2_json "$@"
  jq -r '.apps[] | .name' $json
}

# Dump just the instances data
htd_pm2_app_json() # Name
{
  test -n "$json" || pm2_json "$@"
  printf -- "["
  jq '.apps[] | select(.name=="'"$1"'")' "$json"
  printf -- "]"
}

# Pipe JSON for app-name to `pm2 start` command.
htd_pm2_start_if_stopped() # Name
{
  test -n "$1" || error "pm2 start: name expected" 1
  local pid=$(pm2 pid "$1") name="$1" ; shift
  test -n "$pid" && {
    std_info "'$name' is not running"
  } || {
    test -n "$json" || pm2_json "$@"
    htd_pm2_app_json "$name" | pm2 start - &&
        note "pm2 '$name' started" ||
        error "pm2 start $name: $?" 1
  }
}

htd_pm2_stop_if_running() # Name
{
  test -n "$1" || error "pm2 stop: name expected" 1
  local pid=$(pm2 pid "$1") name="$1" ; shift
  test -z "$pid" && {
    std_info "'$name' is not running"
  } || {
    pm2 -s delete "$name" &&
        note "pm2 '$name' stopped" || error "pm2 stop $name: $?" 1
  }
}
