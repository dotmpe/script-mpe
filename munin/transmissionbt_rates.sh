#!/bin/bash
# This is for transmission 2.03

case $1 in
   config)
        cat <<'EOM'
graph_title Transmission up/down rate
graph_vlabel Rate (KB/s)
graph_category Transmission
downrate.label Download rate
uprate.label Upload rate
EOM
        exit 0;;
esac

. /usr/share/munin/plugins/transmissionbt.sh

get_file torrent-list \
	| grep '\<Sum\>' \
	| awk '{print "downrate.value "$(NF)"\nuprate.value "$(NF-1)}'


