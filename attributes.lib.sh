
attributes_lib__load ()
{
  : "${CONFIG_INCLUDE:=${US_BIN:-$HOME/bin}/etc:${XDG_CONFIG_HOME:-$HOME/.config}:/etc}"
}


user_script_base ()
{
  local ctx=${at_Script:-user_script}
  echo "$(${ctx}_prefix)$(${ctx}_basename)"
}

user_script_basename ()
{
  : "${user_script_basename:-user-script}"
}

user_script_suite ()
{
  echo "${user_script_suite:-user-tools}"
}

user_script_ext ()
{
  echo "${user_script_ext:-.bash}"
}

user_script_key ()
{
  : ${user_script_key:-${base:-us}}
  echo "${_//[\/.]/-}"
}


user_settings_lookup () # ~ <Basename>
{
  local conf_dir basepath ext basename=${1:?} \
    ctx=${at_Script:-user_script} \
    ctx2=${at_Settings:-user_settings}

  suite=$(${ctx}_suite) &&
  tool=$(${ctx}_basename) &&
  #key=$(${ctx}_key) &&
  ext=$(std_noerr ${ctx2}_ext || sh_notfound) || return
  prefix= suffix=

  for conf_dir in ${CONFIG_INCLUDE//:/ }
  do
    echo "$conf_dir/$suite/$prefix$basename$suffix$ext"
  done
}

user_settings_paths () # ~ [<Group-names...>]
{
  local pathsepc filelist ctx=${at_Attributes:-attributes}
  if_ok "$(${ctx}_pathspecs "$@")" || return
  for pathspec in $_
  do
    case "$pathspec" in
      ( etc:* ) at_Settings=$ctx user_settings_lookup "${pathspec#etc:}" ;;
      ( meta:* )
        ;; # user_lookup_pathvars SCRIPT_PREFIXES -- "${pathspec#meta:}" ;;
      ( * ) echo "$pathspec" ;;
    esac
  done
}


attributes_groupkey ()
{
  echo "${attributes_groupkey:-attributes_groups}"
}

attributes_pathspecs () # ~ [<Group-names...>]
{
  local groupkey attributeskey ctx=${at_Attributes:-attributes}
  #test 0 -lt $# || set -- $(${ctx}_maingroups)
  groupkey="$(${ctx}_groupkey)" &&
  specskey="$(${ctx}_specskey)" || return
  while test 0 -lt $#
  do
    # Retrieve value for key either from groups array or from specs array
    : "${groupkey}[$1]"
    test -n "${!_:-}" && {
      "${specs_resolve:-true}" "$_" || echo "$_" # echo "$1" "$_"
      set -- $_ "${@:2}"
    } || {
      : "${specskey}[$1]"
      test -n "${!_:-}" && {
        ! "${specs_resolve:-true}" "$_" || echo "$_"
      } || {
        $LOG error :specs-pathspecs "No such group or file" "$1" ${_E_NF?} ||
          return
      }
      shift
    }
  done
}

attributes_raw () # ~ [<Group-names...>]
{
  local attributes filelist ctx=${at_Attributes:-attributes}
  filelist=$(${ctx}_paths "$@") || return
  for attributes in $filelist
  do
    test -s "$attributes" || continue
    echo "# Source: $attributes"
    read_nix_style_file "$attributes" || return
    echo "# EOF"
  done
}

attributes_specskey ()
{
  echo "${attributes_specskey:-attributes_filespecs}"
}

attributes_stddef ()
{
  local {group,specs}key ctx{1,2} script_key
  ctx1=${at_Attributes:-attributes}
  ctx2=${at_Script:-user_script}
  groupkey="$(${ctx1}_groupkey)" &&
  specskey="$(${ctx1}_specskey)" &&
  declare -gA "$groupkey=()" "$specskey=()" &&
  #ctxbasename="$(${ctx}_basename)" &&
  script_key="$(${ctx2}_key)" || return
  # XXX: tested this with declare, but cannot get that to work here.
  set -f
  eval \
    ${groupkey}[local]=\"local-attributes local-script-key-attributes-1\" \
    ${groupkey}[global]=\"global-attributes\" \
    \
    ${specskey}[local-attributes]=\""$(echo {.,meta:,etc:}{,*.}attributes)"\" \
    ${specskey}[global-attributes]=\""$(echo etc:{,*.}attributes)"\" \
    \
    ${specskey}[local-script-key-attributes-1]=\""$(echo {.attributes-${script_key},meta:{,*-}${script_key}.attributes,etc:{,*-}${script_key}.attributes})"\" \
    \
    ${specskey}[script-key-attributes-2]=\""$(echo {.${script_key}.attributes,meta:{,*-}${script_key}.attributes,etc:{,*-}${script_key}.attributes})"\"
  set +f
  stderr script_debug_arrs $groupkey $specskey
}

attributes_tagged ()
{
  false
}

#
