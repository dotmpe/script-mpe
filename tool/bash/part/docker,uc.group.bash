# Copyright: (C) 2026 hari <hari@t470p>
#
# .group.bash file, see User-Conf us-part for specification.
#
# Distributed under terms of the MIT license.

uc_docker_pre=User-Conf.Docker
uc_docker_cnk=2b08d68f
uc_docker_man='

Old style docker run --volume (or -v) maps a host path onto a volume path, or
from a prepared named volume. Flags :ro, :Z or :z change the mount from
read-writable mode to read-only, SELinux shared, and SELinux private label
respectively.

Newer docker run accept --mount, that has explicit type and keywords. Flags
become comma separated tags readonly, Z or z similary suffixed to the option
value argument like -v notation used and with the same default implicit mode of
read-write.'
uc_docker_fun=(
  .generate-volume-args
)

declare -gA \
uc_docker_als=(
)
declare -gA \
uc_docker_ssc=(
)

declare -gA \
uc_docker_hooks=(
  [declare]=\
'declare -g __uc_dckr_="@prefix uc_docker"
declare -gA uc_docker_{volume_map,hostpath_flag}
declare -ga uc_docker_volume_arg'
#  [define]=\
#''
#  [init]=\
#''
)

User-Conf.Docker.generate-volume-args ()
{
: param '<Volume-map> <Args-array> [Special-flag-map] ...'
: input "${1:?Volume map}" Array "[uc_docker_volume=uc_docker_hostpath]"
: input "${2:?Arguments destination array}"
: extended 'This generates old style docker run -v notation, not the newer --mount'
  local -n __uc_dckr_volmap1=${1}
  local -n __uc_dckr_args1=${2}
  local -n __uc_dckr_vflmap1=${3:-uc_docker_hostpath_flag}
  [[ ${__uc_dckr_volmap1[*]:+set} ]] || failerr "Expected volume map" || return
  local -n uc_docker_volume_flag='__uc_dckr_vflmap1["$uc_docker_hostpath"]'
  local -n uc_docker_hostpath='__uc_dckr_volmap1["$uc_docker_volume"]'
  local uc_docker_volume
  for uc_docker_volume in "${!__uc_dckr_volmap1[@]}"
  do
    [[ -d "$uc_docker_hostpath" || -s "$uc_docker_hostpath" ]] ||
      failerr "Missing host path or empty file ${uc_docker_hostpath@Q}" || return
    : "${uc_docker_volume_flag:+:$uc_docker_volume_flag}"
    __uc_dckr_args1+=( "-v" "$uc_docker_hostpath:$uc_docker_volume${_:-:ro}" )
  done
}

# Id: docker,uc                                  vim:set ft=bash sw=2 sts=2 et:
