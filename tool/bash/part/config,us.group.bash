# .group.bash file, see User-Conf us-part for specification.
#
# Copyright 2008-2026 B. van Berkum <dev@dotmpe.com>
#
# Distributed under terms of the MIT license.
us_config_pre=User-Script.Config
us_config_cnk=f2529052
us_config_fun=(
  .declare-keys
  .define-keys
  .detect-commands
  .eval-keys
  .init-config
  .load-keys
)
declare -gA \
us_config_als=(
  [detect_versions]=.detect-commands
  [config_declarekeys]=.declare-keys
  [config_eval]=.eval-keys
  [us_config]=.define-keys
)
declare -gA \
us_config_ssc=(
  [config_assert]='.init-config "${1:-${US_CONFIG_GLOBAL:-${US_CONFIG_PATH%%:*}/us.bash}}"'
  [config_assertlocal]='! (($#)) || failerr "No arguments expected" $_E_GAE || return
User-Script.Config.init-config "${US_CONFIG_LOCAL:-$METADIR/config/us.bash}"'
)

declare -gA \
us_config_hooks=(
  [init]=\
'if_ok "${US_UC_CACHE:=$(command -v config,user.data.bash)}" ||
  failerr "Missing us-config cache filepath setting" || return
: "${US_CONFIG_PATH:=$HOME/.config/user-script:$HOME/.local/etc/us}"
[[ -s $HOME/.config/user-script/us.bash ]] &&
US_CONFIG_GLOBAL=$HOME/.config/user-script/us.bash ||
  _ failerr "Empty or no global User Script config, did you configure the host?"
[[ -s $METADIR/config/us.bash ]] &&
US_CONFIG_LOCAL=$METADIR/config/us.bash ||
  _ failerr "Empty or no local User Script config, run configure"
declare -ga us_uc_env{,dirty} &&
declare -gA us_uc_{{cmd,bin}ver,envdef}'
  [user+load]=\
'cache_loadmaps "$US_UC_CACHE" us_uc_envdef'
)

User-Script.Config.init-config ()
{
: about '...'
  if [[ -s "$1" ]]
  then
    local {init,config}_lines line
    # Read stdin lines as init-lines, and compare aginast current config
    mapfile -t init_lines
    mapfile -t config_lines < <(User-Script.OS.file-data "$1")
    for line in "${init_lines[@]}"
    do
      User-Script.Array.find-string config_lines "$line" ||
        echo "$line" >> "$1"
    done
  else
    >&2 mkdir -vp "${1%/*}" && {
      echo "# User-Script config"
      cat
    } > "$1"
  fi
}

User-Script.Config.declare-keys ()
{
: about 'Declare static Bash string expressions'
: input "${1:?$FUNCNAME${*:+ ${*@Q}}: Key name}"
  local _us_envkey=${1} _us_envval=${2-}
  local -n _us_envdef='us_uc_envdef["$_us_envkey"]'
  cache_setmap "$US_UC_CACHE" "${!_us_envdef}" "$_us_envval"
}

User-Script.Config.define-keys ()
{
: about 'Declare static Bash string expressions'
: example '~ -n|--declare KEY VALUE [KEY VALUE...]'
: example '~ -D|--define KEY [KEY...]'
: example '~ -e|--load'
: example '~ -E|--reset'
  local reset=0
  while [[ $# -gt 0 ]]; do
    case "${1}" in
      ( -D | --define )
          us_uc_envdirty+=( "$2" ) && shift 2 || return
          while [[ $# -gt 0 && ${1} != -* ]]; do
            us_uc_envdirty+=( "$1" ) && shift || return
          done
        ;;
      ( -E | --reset ) reset=1 ;;
      ( -e | --load ) reset=0 ;;
      ( -n | --declare )
          config_declarekeys "${@:2:2}" &&
          us_uc_envdirty+=( "$2" ) && shift 3 || return
          while [[ $# -gt 0 && ${1} != -* ]]; do
            config_declarekeys "${@:1:2}" &&
            us_uc_envdirty+=( "$1" ) && shift 2 || return
          done
        ;;
      ( * ) false ;;
    esac || failerr "Unexpected argument: ${1@Q}" || return
  done

  # XXX: partial update here. for proper dirty handling, need to mark all
  # references as dirty as well
  local -n _env _dirty='us_uc_envdirty[i]'
  for (( i = 0; i < ${#us_uc_envdirty[*]}; i++ ))
  do
    _env="$_dirty"
    if ((reset)) || [[ ! ${_env:+set} ]]; then
      User-Script.Config.eval-keys "$_dirty" || return
    fi
    unset "${!_dirty}"
  done
}

User-Script.Config.detect-commands ()
{
: about 'Track installed command path and version'
: input "${*:?$FUNCNAME${*:+ ${*@Q}}: Command name(s)}"
  local cmd
  local -n verref='us_uc_binver["$cmd"]' vercmd='us_uc_cmdver["$cmd"]'
  for cmd
  do
    User-Script.OS.x.command-assert "$cmd" &&
    verref=$("$cmd" ${vercmd:---version}) ||
      failerr "E$? Determining ${cmd@Q} version"
  done
}

User-Script.Config.eval-keys ()
{
: input "${*:?$FUNCNAME${*:+ ${*@Q}}: Key name(s)}"
  local key
  local -n _def='us_uc_envdef["$key"]'
  while (($#))
  do
    key=$1
    [[ ${_def:+set} ]] ||
      failerr "Missing definition for env ${key@Q}" || return
    # Resolve all placeholders
    local j=0
    while [[
      ${_def:$j} =~ \$([A-Z_][A-Za-z0-9_]+) ||
      ${_def:$j} =~ \${([A-Z_][A-Za-z0-9_]+)
    ]]
    do
      local -n _env=${BASH_REMATCH[1]}
      [[ ${_env:+set} ]] || {
        set -- "${!_env}" "$@"
        continue
      }
      ((j+=${#BASH_REMATCH[0]}))
    done
    # Expand value
    #! ((DEBUG)) || ! ((VERBOSE)) ||
    #  >&2 echo "Expanding ${1@Q} value from ${_def@Q}"
    local -n _env=$1
    _env=$(. <(echo "echo \"$_def\"")) &&
    shift ||
      failerr "E$? getting ${1@Q} value from ${_def@Q}" || return
  done
}

User-Script.Config.load-keys ()
{
: input "${*:?$FUNCNAME${*:+ ${*@Q}}: Key name(s)}"
  (($#)) || set -- /etc/uc/{host,user/$USER}.envd.bash
  TODO "$FUNCNAME $*"
}

# Id: config,us         vim:set ft=bash sw=2 sts=2 et:
