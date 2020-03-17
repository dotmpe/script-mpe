htd__mux()
{
  test -n "$1" || set -- "docker-"
  test -n "$2" || set -- "$1" "dev"
  test -n "$3" || set -- "$1" "$2" "$(hostname -s)"

  note "tmuxinator start $1 $2 $3"
  tmuxinator start $1 $2 $3
}


htd_man_1__tmux='Unless tmux is running, get a new tmux session, based on the
current environment TMUX_SOCK and/or a name in TMUX_SDIR. See `htd tmux get`.

If tmux is running with an environment matching the current, attach. Different
tmux environments are managed by using seperate sockets per session.

Matching to a socket is done per user, an by the values of env vars set with
Htd-TMux-Env. By default it tracks hostname and CS (color-scheme light or dark).
::

    <TMux-SDir>/tmux-<User-Id>/htd<Env-Var-Names>

Ohter commands deal with

Start tmux, tmuxinator or htd-tmux with given names.
TODO: first deal with getting a server and session. Maybe later per window
management.

  tmux list-sockets | sockets
    List (active) sockets of tmux servers. Each server is a separate env with
    sessions and windows.

  tmux list [ - | MATCH ] [ FMT ]
    List window names for current socket/session. Note these may be empty, but
    alternate formats can be provided, ie. "#{window_index}".

  tmux list-windows  [ - | MATCH ] [ FMT ]

  tmux get [SESSION-NAME [WINDOW-NAME [CMD]]]
    Look for session/window with current selected server and attach. The
    default name arguments may dependent on the env, or default to Htd/bash.
    Set TMUX_SOCK or HTD_TMUX_ENV+env to select another server, refer to
    tmux-env doc.

  tmux current | current-session | current-window
    Show combined, or session name, or window index for current shell window

  tmux show TMux Var-Name
  tmux stuff Session Window-Nr String
  tmux send Session Window-Nr Cmd-Line

  tmux resurrect
    See tmux-resurrect for help on dumpfiles.
'
htd__tmux()
{
  tmux_env_req 0
  test -n "$1" || set -- get

  case "$1" in
    list-sockets | sockets ) shift ; htd_tmux_sockets "$@" || return ;;
    list ) shift ; htd_tmux_list_sessions "$@" || return ;;
    list-windows ) shift ; htd_tmux_session_list_windows "$@" || return ;;
    current-session ) shift ; tmux display-message -p '#S' || return ;;
    current-window ) shift ; tmux display-message -p '#I' || return ;;
    current ) shift ; tmux display-message -p '#S:#I' || return ;;

    # TODO: find a way to register tmux windows by other than name; PWD, CMD
    # maybe need to record environment profiles per session
    show ) shift ; $tmux show-environment "$@" || return ;;

    stuff ) shift ; $tmux send-keys -t $1:$2 "$3" || return ;;
    send ) shift ; $tmux send-keys -t $1:$2 "$3" enter || return ;;

    resurrect ) shift ; htd__tmux_resurrect "$@" || return ;;

    * ) subcmd_prefs=${base}_tmux_ try_subcmd_prefixes "$@" || return ;;
  esac

  # TODO: cleanup old tmux setup
  #while test -n "$1"
  #do
  #  func_exists "$func" && {

  #    # Look for init subcmd to setup windows
  #    note "Starting Htd-TMux $1 (tmux-$fname) init"
  #    try_exec_func "$func" || return $?

  #  } || {
  #    test -f "$UCONFDIR/tmuxinator/$fname.yml" && {
  #      note "Starting tmuxinator '$1' config"
  #      htd__mux $1 &
  #    } || {
  #      note "Starting Htd-TMux '$1' config"
  #      htd__tmux_init $1
  #    }
  #  }
  #  shift
  #done
}


htd_man_5__tmux_resurrect='The tmux-resurrect dumps come as a line-based
file format, with three types of lines: several windows, and panes for windows,
and a state line.

1       2    3      4           5     6    7    8  9     10    11
Window: Name Index  active-idx? bits? layout/geom?
Pane:   Name Index? Colon-Title num? bits? num? Pwd num? name? Cmd
State:  Window-Names?
'

htd_man_1__tmux_resurrect='Manage local tmux-resurrect sessions and configs
(tmux.lib.sh). See htd help tmux.

Env
    $TMUX_RESURRECT ~/.tmux/resurrect

Commands
    list
        Print basenames of all dumps on local box.
    lastname
        Print name of most recent dump.
    panes [Dumpfile]
        Line up window, pane, pwd and command for every dumpfile ever or given.
    names
        Print basenames plus list of window names for all dumps on local box.
    listwindows [Dumpfile]
        List window names (for last session)
    allwindows
        List all names, for every window ever
    table
        Tabulate panel counts for every window.
    info [Window [Dumpfile]]
        Print table or look for window panes in every dumpfile ever.
    drop [last]
        Remove dumpfile and reset
    reset
        Restore "last" link. If no dumpfile is found, call restore first.
    backup-all
        Move all dumpfiles except last to cabinet.
    restore [Date|last]
        Find last

See tmux-resurrect in section 5. (file-formats) for more details.
'
htd__tmux_resurrect()
{
  test -n "$1" || set -- lastname
  subcmd_prefs=tmux_resurrect_ try_subcmd_prefixes "$@"
}

#
