#!/bin/bash
#
#
TYPE=$1
[ -n "$TYPE" ] || { exit 1 ; }

echo $TYPE

case $2 in

	"autoconf")
		echo 'yes'
		;;

	"config")

		echo graph_category sensors
		echo graph_args --base 1000

		case $TYPE in

			temp)
					echo graph_title Temperature
					echo mpe_node1_temp.label Node 1
					echo mpe_node1_temp.type GAUGE
					;;

			hum)
					echo graph_title Humidity
					echo mpe_node1_hum.label Node 1
					echo mpe_node1_hum.type GAUGE
					;;
		esac
		;;

	*)

		case $TYPE in

			temp)
					echo mpe_node1_temp.value $(cat /tmp/mpe_node1_temp)
					;;

			hum)
					echo mpe_node1_hum.value $(cat /tmp/mpe_node1_hum)
					;;
		esac
		;;

esac


