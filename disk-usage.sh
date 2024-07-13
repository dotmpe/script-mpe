#!/usr/bin/env bash

sh_mode strict
lib_require us-fun

declare path mp
declare -A mounts=() devs
declare -A usage mount

#declare -a paths
#paths=( "$@" )

#for path
#do
  #if_ok "$(findmnt -n -o TARGET --target "$path")" &&
  #mounts["$_"]=
  #if_ok "$(findmnt -n -o SOURCE --target "$path")" &&
  #devs["$_"]=
#done

mount_ref () # ~ <Mount-point> <Path>
{
  #sys_debug -debug -diag +quiet ||
  ! sys_debug +debug +diag +quiet ||
    stderr echo "Noticing mount $1 for $2"

  mount["$2"]=$1
  [[ ${mounts["$1"]+set} ]] || {
    if_ok "$(df -h "$1")" &&
    exec <<< "$_" &&
    read &&
    IFS=$' \t\n' read -r _ used size avail usepct _ &&
    usage["$1"]=$used:$size:$avail:$usepct &&
    mounts["$1"]=
  }
}

for path
do
  if_ok "$(findmnt -n -o TARGET --target "$path")" &&
  mount_ref "$_" "$path" &&
  [[ "${usage["$path"]+set}" ]] || {
    if_ok "$(du -hs "$path")" &&
    usage["$path"]=${_%%$'\t'*}
  }
  # If path is a mountpoint, we are not going to scan for actual use (du) but
  # rely on what df reports (and usually much quicker, XXX: but ...)
done

for mp in "${!mounts[@]}"
do
  echo "$mp: ${usage["$mp"]}"
  <<< "${usage["$mp"]}"$'\n' IFS=: read -r used size avail usepct
  for path
  do
    [[ ${mount["$path"]} = "$mp" ]] || continue
    echo "  ${usage["$path"]} $path"
  done
done
