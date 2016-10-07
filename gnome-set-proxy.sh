#! /bin/sh
# Switches the GNOME proxy on/off and 
# can take an optional proxy host+port 

usage ()
{
  cat << CAT
Usage: `basename $0` on|off [host [port]]
CAT
  exit 1
}

[ $# -lt 1 ] && usage

case "$1" in
  "on")
    mode="manual"
    ;;
  "off")
    mode="none"
    ;;
  *)
    usage
    ;;
esac

# Old 2007
#gconftool-2 -t string -s /system/proxy/mode "$mode"
#[ ! -z "$2" ] && \
#gconftool-2 -t string -s /system/http_proxy/host "$2"
#[ ! -z "$3" ] && \
#gconftool-2 -t int -s /system/http_proxy/port "$3"

# 2012
gsettings set org.gnome.system.proxy.socks host "$2"
gsettings set org.gnome.system.proxy.socks port "$3"
gsettings set org.gnome.system.proxy mode "$mode"

