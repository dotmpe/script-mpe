#!/bin/bash
# This is for transmission 2.03

case $1 in
   config)
        cat <<'EOM'
graph_title Total number of torrents
graph_vlabel Count
graph_category transmission
EOM
		for T in   Stopped Idle Seeding Up Down Finished
		do
			echo -n "$T.label " | tr 'A-Z' 'a-z'
			echo $T count
		done
        exit 0;;
esac

. transmissionbt.sh

get_file rateUpload | wc -l | awk '{print "total.value "$(NF)}'

#          | 
for T in   Stopped Idle Seeding Up Down Finished
do
	echo -n "$T.value " | tr 'A-Z' 'a-z'
	get_file rateUpload | grep "\<$T\>" | wc -l
done

