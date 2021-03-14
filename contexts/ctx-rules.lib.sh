#!/bin/sh

at_Hosts__at_Rules__trigger='host:*'
at_Hosts__at_Rules__trigger () # Id Spec
{
  test "$(hostname -s)" = "${2:5}"
}

#
