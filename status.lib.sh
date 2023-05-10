#!/bin/sh

## Key-value storage/service wrappers


status_lib__load ()
{
  true
}

status_lib__init ()
{
  true #lib_require
}


status_key () # ~
{
    false
}

status_key_globalize ()
{
  echo "$hostname.$username.$1"
}

#
