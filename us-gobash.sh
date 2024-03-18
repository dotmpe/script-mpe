sh_mode strict
CACHE_DIR=/dev/shm/tmp
lib_require sec-mpe

urlres_cachekey_salt=123

lib_require urlres

gobash_dist=https://raw.githubusercontent.com/EngineeringSoftware/gobash/master/hsabog

urlres "$gobash_dist"

#web_deref "$gobash_dist" gobash-dist.sh


#web_fetch "$gobash_dist"

#cachef=$CACHE_DIR/cachefile
#etagf=$CACHE_DIR/etag
#http_deref_cache_etagfile "$cachef" "$etagf" "$gobash_dist"

#if_ok "$(curl 2>/dev/null)"
#source /dev/stdin <<< "$_"
