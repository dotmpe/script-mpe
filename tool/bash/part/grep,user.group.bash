user_grep_pre=User.Grep
user_grep_fun=(
  .at-basedirs
  .grep-extra
  .user-grep
)
# XXX: For now keeping aliases strictly as proper aliases in user-alias
#user_grep_als=(
#  [grep]=User.Grep.grep-extra
#)

User.Grep.at-basedirs ()
{
: param '~ <Cmd-arr> <Basedirs...>'
  local -n grep_at_cmdargs=${1:?}
  shift
  [[ ${grep_at_cmdargs[*]:+set} ]] ||
    failerr "$FUNCNAME grep command array required" || return
  local bd
  (($#)) && for bd
  do
    std_quiet pushd "$bd" || return
    "${QUIET:-false}" ||
      >&2 echo "$bd> $ grep [opts] '${grep_at_cmdargs[*]}'"
    >&2 echo grep "${grep_opts[@]}" "${grep_at_cmdargs[@]}" || true
    grep "${grep_opts[@]}" "${grep_at_cmdargs[@]}" || true
    std_quiet popd
  done
}

User.Grep.grep-extra ()
{
: about 'Example of wrapper for standard grep with added functionality'
  : TODO 'Wrappers like this could be defined more generically as hooks'
  local argi
  for ((argi=0; argi < $#; argi++))
  do
    case "${!argi}" in
    ( --browse )
        # Provide an easy to browse view of just truncated lines for a big
        # grep invocation, and don't clutter up current terminal.
        # TODO: may want to break this up: have specific venv here or in
        # subshell, and streamline VTE wrapping outside of grep alias (see --new)
        (
          . "${VIRTUAL_ENV_BASEDIR:?}/${PY_VENV_NAME:-script-mpe-pyvenv}"/bin/activate &&
          printf -v grepcmd ' %q' "${@:0:argi-1}" "${@:argi+1}" &&
          grepcmd="grep --color=always $grepcmd" &&
          >&2 echo ">" "command $grepcmd | command less -SR" &&
          TITLE="$$ \$ $_" python ~/bin/tool/urwid/x/urwid-terminal-emulator.py \
            bash -ic "${grepcmd} | less -SR"
        )
        return
      ;;

    ( --lines )
        # FIXME: better alternative to VTE launch, but cant make less prompt strings
        # work entirely. Maybe ajusting LINES is a more direct way to keep
        # a command line in view during load.
        local grepcmd
        printf -v grepcmd ' %q' "${@:0:argi-1}" "${@:argi+1}" &&
        grepcmd="grep --color=always $grepcmd" &&
          #LESS= command less -i -w -z-4 -g -M -R -S \
        command grep --color=always "${@:0:argi-1}" "${@:argi+1}" |
          command less -R -S \
            -Pw"Reading..." \
            -PM"Command done: $grepcmd."
          #-Ps"Ps " \
        return
      ;;

    ( --new )
        local -I window_role
        : "${window_role:=auxiliary}"
        local greparg grepcmd fullcmd ipcresp
        printf -v greparg ' %q' "${@:0:argi-1}" "${@:argi+1}" &&
        grepcmd="grep --color=always $greparg" &&
        >&2 echo ">" "$grepcmd | less -SR" &&
        fullcmd="command $grepcmd | command less -SR" &&
        # See user-i3wm, and i3 config. Some apps could provide --role, or
        # class. For urxvt it accepts -name and that ends up in the
        # first value of the WM_CLASS tuple property where i3 will match this
        # with for_window [instance="auxiliary"] rules.
        ipcresp=$(win_new "urxvt -name ${window_role} --title \"$grepcmd\" -e bash -c \"$fullcmd\"")
        return
    esac
  done
  grep "${@}"
}

User.Grep.user-grep ()
{
: input "${*:?$FUNCNAME: Command args undefined, $ENV_CTX}"
  case "${1}" in
  ( --basedirs* )
        # FIXME: inject user config instead of lazy loading here
        : "${US_SCR_EXT:=.us.group.bash .group.bash .bash .sh}"
        : ${1#--basedirs}
        : ${_#:}
        local spec=${_:-user-script}
        require "common,script,user" &&
        user_script_basedirs --${spec} basedirs
      ;;

  ( --git-grep )
      : about '<Git-grep-args...> [-- <Treedirs...>]'
      local -a git_args git_grep_args basedirs
      # Read grep-argv (including regex and filename pattern(s)) until first '--'
      if _Sys_Argv_Firstseq git_grep_args "${@:2}"
      then
        : # Grep-args provided only, use default base dirs array
        "$FUNCNAME" --basedirs:user-script || return
      elif [[ $? -eq ${_E_continue:-195} ]]
      then
        # Grep-args and base dirs provided by user
        basedirs=( "${@:  ${#git_grep_args[*]} + 2}" )
      else
        return ${_E_GAE:?}
      fi
      # TODO: inject user or local host, basedir cq project config
      [[ ${#git_grep_args[*]} -gt 1 ]] || git_grep_args+=( '*.sh' )
      git_grep_args=( --recurse-submodules "${git_grep_args[@]}" )
      # XXX: setting PAGER= toggles off core.pager for GIT (git-delta) as well
      [[ ${PAGER-} ]] || git_args+=( "-c" "core.pager=" )
      "$FUNCNAME" :git-grep-dirs:basedirs
    ;;

  ( --git-grep-versions )
      : param '<Pattern> <Files...>'
      : about 'Search entire Git revision listing'
      : param '<Pattern> <Nameglob> <Basedirs...>'
      local -a git_args git_grep_args=( "${@:2:2}" ) basedirs=( "${@:4}" )
      TODO "Need to fetch rev-list at each base"
      #[[ ${basedirs[*]:+set} ]] ||
      #  "$FUNCNAME" --basedirs:user-script || return
      #User-Scripts.System.read-call git_grep_args git rev-list ${GIT_REVOPT:=--all} &&
      #"$FUNCNAME" :git-grep-dirs:basedirs
    ;;


  # TODO: change to use Git.Grep.at-basedirs
  ( :git-grep-dirs:* )
      ! (($#-1)) || return ${_E_GAE:?}
      local -n __gg_bd=${1#:git-grep-dirs:}
      local bd
      for bd in "${__gg_bd[@]}"
      do
        [[ -e "$bd/.git" ]] || {
          >&2 echo "Not a Git basedir <$bd>"
          continue
        }
        std_quiet pushd "$bd" || return
        "${QUIET:-false}" ||
          >&2 echo "$bd> $ git grep '${git_grep_args[*]}'"
        git "${git_args[@]}" grep "${git_grep_args[@]}" || continue
        std_quiet popd
      done
    ;;

    * ) return ${_E_nsc:?}
  esac
}

#
