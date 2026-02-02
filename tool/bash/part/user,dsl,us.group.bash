# TODO: cache specified name alias and static functions
# ~/.bash_alias,dsl,uc or us

us_dsl_user_pre=User.DSL
us_dsl_user_grp=( uc-basedir )
us_dsl_user_fun=(
  .load-user-command
  .user-main-autostart
  .user-ops-main
  #user{,-{init,sync}}
)

declare -gA \
us_dsl_user_als=(
  [user]=.user-main-autostart
  [user-load]=.load-user-command
)

declare -gA \
us_dsl_user_ssc=(
  [TODO]='failerr "${1:-TODO: ${FUNCNAME[1]}}" ${_E_missing:-125}'
)

User.DSL.load-user-command ()
{
: "${US_SCR_EXT:=.us.group.bash .group.bash .bash .sh}"
: "${METADIR:=/tmp}"
: "${C:=/tmp/cache}"
  usercmd_parts=( user-command us-dsl-user )
  # XXX: loadcmd uses User-Script.require, not User-Script.part
  us_part --alias --hooks:declare,define,init uc-command uc-cache &&
  loadcmd usercmds \
      uc-user-dirs \
      uc-user-shares \
      uconf-annex \
      uc-user-torrents \
      uc-user-command \
      uc-user-music ||
    failerr "E$? while loading user commands" || return
  # Add an extra layer for hacking, but should integrate everything with
  # user-command and other groups properly.
  us_part --reload --alias "${usercmd_parts[@]}" &&
  initcmd usercmds User.Command.user-main User.DSL.user-ops-main
}

User.DSL.user-main-autostart ()
{
  local ns_at=$FUNCNAME
  [[ ${usercmds[*]:+set} ]] || {
    >&2 echo "user: Initial run, loading..."
    User.DSL.load-user-command || return
    >&2 echo "user: commands loaded, starting 'user $*' ..."
  }
  (($#)) || return ${_E_MA:?}
  runcmd usercmds "$@"
}

User.DSL.user-ops-main ()
{
  local ns_here=$FUNCNAME ctx=${ENV_CTX:-[$$/$0]} lk=${lk:+$lk:$FUNCNAME}
  : "${lk:=$(sh_call_context)}"
: input "${*:?$FUNCNAME: Command args undefined, $ctx:$lk}"
  case "${1:?}" in
  ( _:"${FUNCNAME}":init )
      append_lookup /var/local/statusdir SCRIPTPATH &&
      lib_require todotxt-fields &&
      User-Conf.Basedir.basedirs+load
    ;;

  ( --basedir-edit )
      local -a data_f data_refs
      # shellcheck disable=2054 # commas are in names
      data_refs=(
        basedir,user.data.bash
        user,dsl,us.data.bash
        user,dsl,us.group.bash
        basedir,uc.data.bash
        basedir,uc.group.bash
      )
      for ref in "${data_refs[@]}"
      do
        if_ok "$(PATH=$SCRIPTPATH command -v $ref)" &&
        data_f+=( "$_" ) || failerr "No script for $ref"
      done
      $EDITOR "${data_f[@]}"
    ;;

  ( --basedir-command )
      local -I PWD
      local -n bdid='uc_basedir_pathid["$PWD"]'
      local -n cmd='user_basedir_'${2:?}'[$bdid]'
      [[ ${cmd:+set} ]] || PWD=$(realpath "$PWD")
      [[ ${cmd:+set} ]] ||
        failerr "No $2 command for current dir" || return
      echo "Starting basedir-command ${2@Q} for $PWD..."
      eval "$cmd"
    ;;

  ( --basedir-command-tree )
      local path cmd path_header
      local -n pathid='uc_basedir_pathid["$path"]'
      for path in "${!uc_basedir_pathid[@]}"
      do
        path_header=0
        for cmd in "${uc_basedir_commands[@]}"
        do
          local -n cmddefs="user_basedir_$cmd"
          [[ ${cmddefs[pathid]:+set} ]] || continue
          ((path_header)) || echo "$path:"
          path_header=1
          echo "  $ $cmd"
        done
      done
    ;;

  ( --basedir-commands )
      local -I PWD
      local -n bdid='uc_basedir_pathid["$PWD"]'
      [[ ${bdid:+set} ]] ||
        failerr "No path-Id for $PWD" || return
      local -n cmd
      local found=0 indent='|        '
      for cmd in $(compgen -A arrayvar -X '!user_basedir_*')
      do
        [[ ${cmd[bdid]:+set} ]] || continue
        : ${!cmd}
        : ${_#user_basedir_}
        printf '%s $ %s\n%s\n' "$PWD" "${_}" \
          "$indent${cmd[bdid]//$'\n'/$'\n'$indent}"
        found=1
      done
      ((found)) || failerr "No commands found for $PWD"
    ;;

  ( --basedir-reload )
      User-Conf.Basedir.basedirs+load
    ;;


  ( init )
      here --basedir-command init "$@"
    ;;

  ( init+fromtab )
      # shellcheck disable=2317 # ignore unreachable command (function)
      # Read the tab into Bash, and also check local host env
      _us_bd_initfromtab () {
        local path id
        # Build lookup map for symbol to (numeric) id
        id=${uc_basedir_id["$todotxt_key"]:-${todotxt_meta_tags[id]:-${#uc_basedir_id[@]}}}
        [[ ${uc_basedir_id[$todotxt_key]:+set} ]] || {
          uc_basedir_id["$todotxt_key"]=$id
          echo uc_basedir_id[$todotxt_key]=$id >> "$uc_basedir_bash"
        }
        # Build lookup for paths as well
        for path in "${todotxt_file_refs[@]}"
        do
          User-Script.OS.x.expand-pathref path
          #[[ -e "$path" ]] || continue
          [[ ${uc_basedir_pathid[$path]:+set} ]] || {
            uc_basedir_pathid["$path"]=$id
            echo uc_basedir_pathid[$path]=$id >> "$uc_basedir_bash"
          }
        done
      }
      todotxt_readtab "/var/local/statusdir/basedirs.tab" _us_bd_initfromtab
    ;;

  ( sync )
      here --basedir-command sync "$@"
    ;;

  ( update )
      here --basedir-command update "$@"
    ;;

  ( * ) return ${_E_nsc:?}
  esac
}

#
