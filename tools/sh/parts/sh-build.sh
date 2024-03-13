
# XXX: see ac-util
#declare -gA user_build
#
#user_build_dep[user-shell-commands:a]=PATH
#user_build[user-shell-commands:array]=us_exec_commands

# Build (and evaluate) target symbol if needed
sh_build_sym () # ~ <Target> <Source...>
{
  case "${target:=${1:?}}" in
    ( *:c | *:command )
      ;;
    ( *:a | *:alias )
      ;;
    ( *:array )
      ;;
  esac
}

sh_build_array () # ~ <Var-name> <Key> <Cmd...>
{
  sh_arr "${1:?}" && return
  declare cache{bn,}
  cachebn=${STATUSDIR_ROOT:?}cache/sh-build-array:${1//[^A-Za-z0-9-]/-}
  cache=$cachebn.sh
  test -e "$cache" -a -e "$cachebn.key" &&
  test "${2:?}" = "$(<"$cachebn.key")" || {
    #stderr echo "(Re)generating cached array '$1'..."
    sys_arr "${1:?}" "${@:3}" &&
    if_ok "$(declare -p "${1:?}")" &&
    echo "declare -ga ${_:11}" >| "$cache" &&
    echo "${2:?}" >| "$cachebn.key" || return
  }
  source "$cache" &&
  sh_arr "$1"
}

#
