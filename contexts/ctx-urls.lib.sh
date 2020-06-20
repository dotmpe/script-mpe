#!/bin/sh

ctx_urls_lib_load()
{
  true
}

ctx_urls_lib_init()
{
  trueish "$global" && {
    urlstat=$(sd root index urlstat.list)
  } || {
    urlstat=$(sd find index urlstat.list)
  }
}

at_URLs__list()
{
  todotxt_tagged $urlstab "$@"
}

at_URLs__rules_sh() # ~ Dest-Cmd Tags
{
  true
}

#
