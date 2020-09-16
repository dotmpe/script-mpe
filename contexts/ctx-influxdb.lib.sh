#!/usr/bin/env bash

#at_Shell__ps1="path=\$path:\$()"
at_Composure__include=influx.inc
at_SystemD__service=docker.influxdb
at_UserConf__Tools__influx="alias influx='docker exec -ti \$hostname-influxdb influx'"
