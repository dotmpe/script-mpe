#!/usr/bin/env bash

ctx_influx_lib_init ()
{
  test ${ctx_influx_lib_init:-1} -eq 0 || true
}

#at_Shell__ps1="path=\$path:\$()"
at_Composure__include=influx.inc
at_SystemD__service=docker.influxdb
at_UserConf__Tools__influx="alias influx='docker exec -ti \$hostname-influxdb influx'"
