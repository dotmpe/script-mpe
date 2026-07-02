# TODO: cache specified name alias and static functions
# ~/.bash_alias,dsl,uc or us

us_dsl_user_pre=User.DSL
us_dsl_user_fun=(
  .load-user-command
  .user-main-autostart
  .user-ops-main
  #user{,-{init,sync}}
)

declare -gA \
us_dsl_user_als=(
  #[user]=User.DSL.user-main-autostart
  [user]=.user-main-autostart
  [user-command-start]=.load-user-command
  #[user-load]='us_part ${usp_opts} uc-command us-dsl-user && User.DSL.load-user-command'
  #[@user/basedirs]=.user-ops-main
  [@user/*]=.user-ops-main
)

declare -gA \
us_dsl_user_ssc=(
  [TODO]='failerr "${1:-TODO: ${FUNCNAME[1]}}" ${_E_missing:-125}'
)

declare -gA \
us_dsl_user_hooks=(
)

User.DSL.load-user-command ()
{
: "${US_SCR_EXT:=.us.group.bash .group.bash .bash .sh}"
: "${METADIR:=/tmp}"
: "${C:=/tmp/cache}"
# XXX: need better dep mngmt to load from sensible user data. For later.
# See also --edit etc. in uc-user-command
  usercmd_parts=()
  usercmd_dev_parts=( user-command us-dsl-user )
# XXX: loadcmd uses User-Script.require, not User-Script.part.
  us_part --alias --hooks:declare,define,init uc-command uc-cache &&
  loadcmd user \
      us-dsl-user \
      uc-user-dirs \
      uc-user-shares \
      uconf-annex \
      uc-user-command \
      uc-user-journal \
      uc-user-torrents \
      uc-user-music ||
    failerr "E$? while loading user commands" || return

  # Add an extra layer for hacking, but should integrate everything with
  # user-command and other groups properly.
  #us_part --reload --alias "${usercmd_dev_parts[@]}" &&
  : #initcmd usercmds User.Command.user-main User.DSL.user-ops-main
}

User.DSL.user-main-autostart ()
{
  local ns_at=$FUNCNAME
  [[ ${usercmds[*]:+set} ]] || {
    >&2 echo "user: Initial run, loading..."
    User.DSL.load-user-command ||
      failerr "E$? loading user command" || return
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
  ( _:user:init )
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
