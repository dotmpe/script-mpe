#!/bin/sh


# XXX: other
docstat_parse_thing_descr()
{
  test -z "$1" || fdate=$1 # First seen
  test -z "$2" || ldate=$2 # Last seen
  export fdate ldate
}
