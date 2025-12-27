# TODO: cache specified name alias and static functions
# ~/.bash_alias,dsl,uc or us
# shellcheck disable=2317

us_dsl_user_fun=(
  user{,-{init,sync}}
)

declare -gA \
us_dsl_user_ssc=(
  [TODO]='failerr "${1:-TODO: ${FUNCNAME[1]}}" ${_E_missing:-125}'
)

user ()
{
  local ns_at=$FUNCNAME
  [[ ${usercmds[*]:+set} ]] || {
    >&2 echo "user: Initial run, loading..."
    # XXX: loadcmd uses User-Script.require, not User-Script.part
    us_part --alias --hooks:declare,define,init us-ns uc-command user-command &&
    US_SCR_EXT=.us.group.bash\ .group.bash\ .bash\ .sh &&
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
    initcmd usercmds user-main user-ops
    >&2 echo "user: commands loaded, starting 'user $*' ..."
  }
  runcmd usercmds "$@"
}

user_ops ()
{
  local ns_here=$FUNCNAME ctx=${ENV_CTX:-[$$/$0]} lk=${lk:+$lk:$FUNCNAME}
  : "${lk:=$(sh_call_context)}"
  : input "${*:?$FUNCNAME: Command args undefined, $ctx:$lk}"
  #>&2 echo "$FUNCNAME $*"
  case "${1:?}" in
  ( _:${FUNCNAME//_/-}:init )
      lib_require todotxt-fields &&
      User-Config.Basedir.basedirs+load
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

  ( init )
      user_ops --basedir-command init "$@"
    ;;

  ( init+fromtab )
      # Read the tab into Bash, and also check local host env
      _us_bd_initfromtab () {
        local path id
        # Build lookup map for symbol to (numeric) id
        id=${uc_basedir_id[$todotxt_key]:-${todotxt_meta_tags[id]:-${#uc_basedir_id[@]}}}
        [[ ${uc_basedir_id[$todotxt_key]:+set} ]] || {
          uc_basedir_id[$todotxt_key]=$id
          echo uc_basedir_id[$todotxt_key]=$id >> "$uc_basedir_bash"
        }
        # Build lookup for paths as well
        for path in "${todotxt_file_refs[@]}"
        do
          User-Script.OS.x.expand-pathref path
          #[[ -e "$path" ]] || continue
          [[ ${uc_basedir_pathid[$path]:+set} ]] || {
            uc_basedir_pathid[$path]=$id
            echo uc_basedir_pathid[$path]=$id >> "$uc_basedir_bash"
          }
        done
      }
      todotxt_readtab "/var/local/statusdir/basedirs.tab" _us_bd_initfromtab
    ;;

  ( sync )
      user_ops --basedir-command sync "$@"
    ;;

  ( update )
      user_ops --basedir-command update "$@"
    ;;

  ( * ) return ${_E_nsc:?}
  esac
}

#
