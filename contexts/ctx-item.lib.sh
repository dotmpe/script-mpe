#!/bin/sh


docstat_parse_item_descr()
{
  test -z "$1" || bdate=$1 # Birth/created
  test -z "$2" || udate=$2 # Last-Update
  test -z "$3" || cdate=$3 # Closed
  test -z "$4" || ddate=$4 # Deleted/destroyed
  export bdate udate cdate ddate
}
