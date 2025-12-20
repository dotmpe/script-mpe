# TODO: cache specified name alias and static functions
# ~/.bash_alias,dsl,uc or us
# But not sure about formats yets

us_dsl_user_fun=(
  user
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
    us_part --alias --hooks:declare,define,init us-ns uc-command &&
    US_SCR_EXTS=.group.bash\ .bash\ .sh &&
    loadcmd usercmds \
        uc-user-dirs \
        uc-user-shares \
        uconf-annex \
        uc-user-torrents \
        uc-user-command \
        uc-user-music ||
      failerr "E$? while loading user commands" || return
    >&2 echo "user: commands loaded, starting 'user $*' ..."
  }
  runcmd usercmds "$@"
}

#
