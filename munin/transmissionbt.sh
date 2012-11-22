#!/bin/bash
# fields:
# https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt
# rateUpload
# rateDownload
# percentDone
function get_file() # field 
{
	TMPF=/tmp/transmissionbt-munin-$1-stats

	if test -e $TMPF
	then
		OLD=$(stat -c %Z $TMPF)
		NOW=$(date +%s)
		AGEMINUTES=$(( ( $NOW - $OLD ) / 60 ))
		if [ $AGEMINUTES -ge 4 ];
		then
			rm $TMPF
		fi
	fi

	if test ! -e $TMPF
	then
		echo '{"method":"torrent-get","tag":1,"arguments":{"fields":["'$1'"]}}' \
			| transmission-remote -n mpe:tr4bt0 -l \
			> $TMPF
	fi

	cat $TMPF
}

