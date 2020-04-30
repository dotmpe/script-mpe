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

ctx__URLs__list()
{
  todotxt_tagged $urlstab "$@"
}

ctx__URLs__rules_sh() # ~ Dest-Cmd Tags
{
  true
}
