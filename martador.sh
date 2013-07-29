#!/bin/bash

# todo: should move this to htdocs

case "$1" in
	
	"system-sleep" )
		# suspend to volatile media and pause
		sudo /usr/sbin/pm-suspend
		;;

	"system-save" )
		# suspend to solid media and shutdown
		sudo /usr/sbin/pm-hibernate
		;;

esac

