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

	"system-reboot" )
		sudo reboot
		;;

	"system-shutdown" )
		sudo shutdown -h now
		;;

esac


