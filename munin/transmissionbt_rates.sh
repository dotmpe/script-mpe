#!/bin/bash
# This is for transmission 2.03

case $1 in
   config)
        cat <<'EOM'
graph_title Transmission up/down rate
graph_vlabel Rate (KB/s)
graph_category Transmission
downRate.label Download rate
upRate.label Upload rate
EOM
        exit 0;;
esac

case $1 in
   config)
        cat <<'EOM'
graph_title Total number of torrents
graph_vlabel Count
graph_category transmission
EOM
		for T in   upRate downRate
		do
			echo -n "$T.label " | tr 'A-Z' 'a-z'
			echo $T 
		done
        exit 0;;
esac

. /usr/share/munin/plugins/transmissionbt.sh

get_file rateUpload \
	| grep Sum \
	| awk '{print "downrate.value "$(NF)"\nuprate.value "$(NF-1)}'

