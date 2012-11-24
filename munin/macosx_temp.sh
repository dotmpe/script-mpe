#!/bin/bash

case $1 in
   config)
        cat <<'EOM'
graph_title MacBook Temperatures
graph_vlabel Temperature (C)
graph_category sensors
graph_args --base 1000 -l 0
EOM

/Applications/HardwareMonitor.app/Contents/MacOS/hwmonitor |  \
	grep ':' | \
	sed 's/HTS545032B9SA02\ .101113PBS3004TG2MN9S.//g' | 
	while read l
	do
		Name=$(echo $l | sed 's/^\([^:]*\):.*$/\1/g' )
		ID=$(echo $Name | sed 's/[^A-Za-z0-9]/_/g' )
		echo "$ID.label $Name"
	done 
		
        exit 0;;
esac


/Applications/HardwareMonitor.app/Contents/MacOS/hwmonitor |  \
	grep ':' | \
	sed 's/HTS545032B9SA02\ .101113PBS3004TG2MN9S.//g' | 
	while read l
	do
		Name=$(echo $l | sed 's/^\([^:]*\):.*$/\1/g' )
		ID=$(echo $Name | sed 's/[^A-Za-z0-9]/_/g' )
		Value=$(echo $l | sed 's/^[^:]*:\(.*\)$/\1/g' |sed 's/[C ]//g' )
		echo "$ID.value $Value"
	done 


