#!/bin/sh


# Get the gateway IP for default route
default_route()
{
  # XXX: enabled || { enabled eth0 || { error "Offline" 1; }; }
  default_route=$(echo $(route -n get default | grep gateway) | cut -d ' ' -f 2)
  stderr info "Default route: $default_route"
}


# IP-to-host
IP_to_host()
{
  echo "$1" | grep -q '^[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$' && {
    host "$1" | sed 's/^.*\ \([a-z0-9\.]*\)\.$/\1/g'
  } || {
    echo "$1"
  }
}

# Host-to-IP
host_to_IP()
{
  echo "$1" | grep -q '^[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$' && {
    echo "$1"
  } || {
    host "$1" | sed 's/^.*\ \([a-z0-9\.]*\)\.$/\1/g'
  }
}

ifaces()
{
  /sbin/ifconfig -l
}

# Given file lines have hostnames and aliases. Assume first host on matching
# line in file is special, public/global/canonical
canon_host()
{
  test -n "$2" || return 1
  test -n "$1" || set -- /etc/hosts "$2"
  grep -q "$2" "$1" | awk '{print $2}'
}
