
meta_aprops_lib__load ()
{
  lib_require str-htd
}

meta_aprops_lib__init ()
{
  typeset -gA meta_aprop_{about,obj}
  typeset field
  : "${meta_fields-}"
  : "${_//,/ }"
  for field in $_
  do
    typeset -gA "meta_aprop__${field:?}=()"
  done
  : "${meta_aprops_salt:-$RANDOM}"
}


meta__aprops__commit () # (id) ~
{
  mkdir -p "${meta_path%\/*}" &&
  meta__aprops__dump >| "${meta_path:?}"
}

meta__aprops__direct_get () # ~ <Key>
{
  typeset key=${1:?meta:aprops:get: Key expected}
  grep -Po -m1 "^$key = \K.*" "${meta_path:?}"
}

meta__aprops__direct_set () # ~ <Key> <Value>
{
  typeset key=${1:?meta:aprops:set: Key expected}
  sed -i "s/^$key = .*$/$key = ${2-}/g" "${meta_path:?}"
}

meta__aprops__dump () # ~
{
  typeset key
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
  typeset fp key eq value
  typeset -A meta_keys=()
  exec {fp}< "${meta_path:?}"
  # XXX: optional validate to check function and integrity
  #read -u $fp -r line
  #test "[$meta_ref]" = "$line"
  read -u $fp -r _
  while read -u $fp -r key eq value
  do
    test "$eq" = "=" ||
      $LOG error : "Illegal format" "$key $eq $value" 1 || return
    sh_arr "meta_aprop__${key:?}" || typeset -gA "$_=()"
    typeset -g "meta_aprop__${key:?}[$meta_id]=$value"
    test -n "${meta_keys[$key]+set}" || meta_keys["$key"]=
  done
  exec {fp}<&-
  meta_aprop_obj[${meta_id:?}]=$(printf '%s ' "${!meta_keys[@]}")
  meta_aprop_about[${meta_ref:?}]=${meta_id:?}
}

meta__aprops__init () # (-id:) ~ ( <key> <value> )+
{
  typeset -A meta_keys=()
  while test 0 -lt $#
  do
    test $# -ge 2 || return ${_E_GAE:?}
    sh_arr "meta_aprop__${1:?}" || typeset -gA "$_=()"
    typeset -g "meta_aprop__${1:?}[${meta_id:?}]=${2-}" || return
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
  typeset -g "meta_aprop__${1:?}[${meta_id:?}]=${2-}"
}

meta__aprops__update () # (-id:) ~ ( <key> <value> )+
{
  test $# -ge 2 || return ${_E_MA:?}
  sh_arr meta_keys || typeset -A meta_keys=()
  while test 0 -lt $#
  do
    test $# -ge 2 || return ${_E_GAE:?}
    sh_arr "meta_aprop__${1:?}" || typeset -gA "$_=()"
    typeset -g "meta_aprop__${1:?}[${meta_id:?}]=${2-}"
    test -n "${meta_keys[$1]+set}" || meta_keys[$1]=
    shift 2
  done
  meta_aprop_obj[${meta_id:?}]=$(printf '%s ' "${!meta_keys[@]}")
  meta_aprop_about[${meta_ref:?}]=${meta_id:?}
}


# Util: 'backends' handlers, function to generate cache file names given src

meta_aprops_be1 () # ~ <Set> <Source>
{
  if_ok "$(<<< "$meta_aprops_salt${2:?}" sha1sum)" &&
  : "${_%  -}" &&
  var_set "${1:?}" "${_:0:2}/${_:2}.properties"
}

meta_aprops_be2 () # ~ <Set> <Source>
{
  if_ok "$(<<< "$meta_aprops_salt${2:?}" sha256sum)" &&
  : "${_%  -}" &&
  var_set "${1:?}" "${_:0:2}/${_:2:4}/${_:4}.properties"
}

meta_aprops_ref () # (:meta-{about,ref,path}) ~ <File>
{
  meta_ref="${1:?Meta about ref expected}"
  meta_about=${meta_ref#*:}
  local be_path
  "${meta_aprops_be:-meta_aprops_be1}" local:be_path "$meta_ref"
  meta_path="${APROPS_DIR:?}/$be_path"
}

#
