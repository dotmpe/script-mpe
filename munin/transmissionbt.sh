#!/bin/bash
# fields:
# https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt
# rateUpload
# rateDownload
# percentDone
function get_file() # method field 
{
	#TMPF=/tmp/transmissionbt-munin-$1-stats
	case $1 in
		torrent-list )
			transmission-remote -n mpe:tr4bt0 -l 
			;;
	esac
}

