
meta_aprops_lib__load ()
{
  lib_require str-htd
}

meta_aprops_lib__init ()
{
  declare -gA meta_aprop_{about,obj}
  declare field
  : "${meta_fields-}"
  : "${_//,/ }"
  for field in $_
  do
    declare -gA "meta_aprop__${field:?}=()"
  done
  : "${meta_aprops_salt:=$(stderr echo "!!! dynamic salt set:" $RANDOM; echo $_)}"
  ! sys_debug -dev -debug -init ||
    $LOG notice "" "Initialized meta-aprops.lib" "$(sys_debug_tag)"
}


meta__aprops__commit () # (id) ~
{
  mkdir -p "${meta_path%\/*}" &&
  meta__aprops__dump >| "${meta_path:?}"
}

meta__aprops__direct_get () # ~ <Key>
{
  declare key=${1:?meta:aprops:get: Key expected}
  grep -oP -m1 "^$key = \K.*" "${meta_path:?}"
}

meta__aprops__direct_set () # ~ <Key> <Value>
{
  declare key=${1:?meta:aprops:set: Key expected}
  sed -i "s/^$key = .*$/$key = ${2-}/g" "${meta_path:?}"
}

# TODO: out-fmt
meta__aprops__dump () # ~ <File>
{
  declare key
  echo "[${meta_ref:?}]"
  : "meta_aprop_obj[${meta_id:?}]"
  for key in ${!_:?}
  do
    : "meta_aprop__${key:?}[${meta_id:?}]"
    echo "$key = ${!_-}"
  done
}

meta__aprops__exists () # (-{ref,path}:) ~
{
  meta__aprops__loaded ||
  test -s "${meta_path:?}"
}

meta__aprops__fetch () # (-{id,path}:) ~
{
  declare fp key eq value
  declare -A meta_keys=()
  exec {fp}< "${meta_path:?}"
  # XXX: optional validate to check function and integrity
  #read -u $fp -r line
  #test "[$meta_ref]" = "$line"
  read -u $fp -r _
  while read -u $fp -r key eq value
  do
    test "$eq" = "=" ||
      $LOG error : "Illegal format" "$key $eq $value" 1 || return
    sh_arr "meta_aprop__${key:?}" || declare -gA "$_=()"
    declare -g "meta_aprop__${key:?}[$meta_id]=$value"
    test -n "${meta_keys[$key]+set}" || meta_keys["$key"]=
  done
  exec {fp}<&-
  meta_aprop_obj[${meta_id:?}]=$(printf '%s ' "${!meta_keys[@]}")
  meta_aprop_about[${meta_ref:?}]=${meta_id:?}
}

meta__aprops__init () # (-id:) ~ ( <key> <value> )+
{
  declare -A meta_keys=()
  while test 0 -lt $#
  do
    test $# -ge 2 || return ${_E_GAE:?}
    sh_arr "meta_aprop__${1:?}" || declare -gA "$_=()"
    declare -g "meta_aprop__${1:?}[${meta_id:?}]=${2-}" || return
    test -n "${meta_keys[$1]+set}" || meta_keys["$1"]=
    shift 2
  done
  meta_aprop_obj[${meta_id:?}]=$(printf '%s ' "${!meta_keys[@]}")
  meta_aprop_about[${meta_ref:?}]=${meta_id:?}
}

meta__aprops__loaded () # (-ref:) ~
{
  : "meta_aprop_about[${meta_ref:?}]"
  test -n "${!_+set}"
}

meta__aprops__new () # (:meta-{about,ref,path}) ~ <File>
{
  meta_aprops_ref "file:$1"
}

meta__aprops__obj_id () # ~ <File>
{
  : "meta_aprop_about[file:${1:?}]"
  echo "${!_:?}"
}

meta__aprops__set () # (-id:) ~ <Key> <Value>
{
  declare -g "meta_aprop__${1:?}[${meta_id:?}]=${2-}"
}

meta__aprops__update () # (-id:) ~ ( <key> <value> )+
{
  test $# -ge 2 || return ${_E_MA:?}
  sh_arr meta_keys || declare -A meta_keys=()
  while test 0 -lt $#
  do
    test $# -ge 2 || return ${_E_GAE:?}
    sh_arr "meta_aprop__${1:?}" || declare -gA "$_=()"
    declare -g "meta_aprop__${1:?}[${meta_id:?}]=${2-}"
    test -n "${meta_keys[$1]+set}" || meta_keys[$1]=
    shift 2
  done
  meta_aprop_obj[${meta_id:?}]=$(printf '%s ' "${!meta_keys[@]}")
  meta_aprop_about[${meta_ref:?}]=${meta_id:?}
}


# Util: 'backends' handlers, function to generate cache file names given src

meta_aprops_be1 () # ~ <Var> <Source>
{
  local -n mab__var=${1:?}
  if_ok "$(<<< "${2:?}$meta_aprops_salt" sha1sum)" &&
  : "${_%  -}" &&
  mab__var="${_:0:2}/${_:2}.properties"
}

meta_aprops_be2 () # ~ <Var> <Source>
{
  local -n mab__var=${1:?}
  if_ok "$(<<< "${2:?}$meta_aprops_salt" sha256sum)" &&
  : "${_%  -}" &&
  mab__var="${_:0:2}/${_:2:4}/${_:4}.properties"
}

meta_aprops_ref () # (:meta-{about,ref,path}) ~ <File>
{
  : about "Set meta:{ref,about,path} env"
  meta_ref="${1:?Meta about ref expected}"
  meta_about=${meta_ref#*:}
  local be_path
  "${meta_aprops_be:-meta_aprops_be1}" be_path "$meta_ref"
  meta_path="${APROPS_DIR:?}/$be_path"
}

#
