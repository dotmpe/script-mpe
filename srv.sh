#!/usr/bin/env bash

#lib_require srv
#srv__update_services

: "${U:=${STATUSDIR_ROOT:-$HOME/.local/var/statusdir/}index}"
user=${SUDO_USER:-${USER?}}

mount_basedirs=( /media/${user?} /run/media/${user?} /mnt/nfs /mnt )

. "common,cache,uc.sh"

cache_loadmaps "${U}/user-srv.sh" volume_ids

for volid in "${!volume_ids[@]}"
do
  [[ -h /srv/"$volid" ]] &&
  [[ -e /srv/"$volid"/ ]] && continue
  [[ -h /srv/"$volid" ]] && rm -v /srv/"$volid"
  for volname in ${volume_ids["$volid"]}
  do
    for mountdir in "${mount_basedirs[@]}"
    do
      [[ -e "$mountdir/$volname" ]] || continue
      ln -vs "$mountdir/$volname" /srv/$volid
    done
  done
done
