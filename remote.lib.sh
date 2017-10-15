#!/bin/sh

set -e


on_host()
{
  test "$hostname" = "$1" || return 1
}

req_host()
{
  on_host "$1" || error "$0 runs on $1 only" 1
}

on_system()
{
  test "$uname" = "$1" || return 1
}

# Run command at another host
run_cmd()
{
  test -n "$1" || set -- "$hostname" "$2"
  test -n "$2" || set -- "$1" "whoami"
  test -n "$host_addr_info" || host_addr_info=$hostname

  test -z "$dry_run" && {
    on_host "$1" && {
      $2 \
        && debug "Executed locally: '$2'" \
        || {
          error "Error executing local command: '$2'"
          return 1
        }
    } || {
      # XXX: see MPE_CONF_DEBUG=1 too
      ssh -t $host_addr_info "RC_ENV_OVERRIDE=1 . \$HOME/.bashrc ; $2" \
        && debug "Executed at $host_addr_info: '$2'" \
        || {
          error "Error executing command at $host_addr_info: '$2'"
          return 1
        }
    }
  } || {
    echo "on_host $1 && { '$2'..} || { ssh $host_addr_info '$2'.. }"
  }
}

# Set host_addr_info for SSH connection
ssh_req()
{
  test -n "$host_addr_info" || {
    test -n "$1" || set -- "$hostname" "$2"
    test -n "$2" || set -- "$1" "$(whoami)"
    host_addr_info="$1"
    test -z "$2" || host_addr_info="$2"'@'$host_addr_info
    note "Connecting to $host_addr_info"
  }
}

# Wait for host to come online
wait_for()
{
  test -n "$1" || set -- "$hostname"
  while [ 1 ]
  do
    ping -c 1 $1 >/dev/null 2>/dev/null && break
    note "Waiting for $1.."
    sleep 7
  done
}



