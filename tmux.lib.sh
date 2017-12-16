#!/bin/sh

tmux_lib_load()
{
  default_env TMux-SDir /opt/tmux-socket || true
}


tmux_env_req()
{
  test -n "$TMUX_SOCK" && {
    debug "Using TMux-Sock env '$TMUX_SOCK'"
  } || {
    test -d "$TMUX_SDIR" || mkdir -vp $TMUX_SDIR
    # NOTE: By default have one server per host. Add Htd-TMux-Env var-names
    # for distinct servers based on currnet shell environment.
    default_env Htd-TMux-Env hostname
    TMUX_SOCK_NAME="htd$( for v in $HTD_TMUX_ENV; do eval printf -- \"-\$$v\"; done )"
    export TMUX_SOCK=$TMUX_SDIR/tmux-$(id -u)/$TMUX_SOCK_NAME
    falseish "$1" || {
      test -S  "$TMUX_SOCK" ||
        error "No tmux socket $TMUX_SOCK_NAME (at '$TMUX_SOCK')" 1
    }
    debug "Set TMux-Sock env '$TMUX_SOCK'"
  }
  tmux="tmux -S $TMUX_SOCK "
}


htd_tmux_sockets_cleanup()
{
  for socket in $TMUX_SDIR/tmux-[0-9]*/*
  do
    tmux -S $socket list-sessions || {
      rm $socket
      note "Cleaning socket $socket"
    }
  done
}


htd_tmux_init()
{
  test -n "$1" || error "session name required" 1
  test -n "$2" || set -- "$1" "bash"
  test -z "$4" || error "surplus arguments: '$4'" 1
  tmux_env_req 0
  # set window working dir
  test -e $UCONFDIR/script/htd/tmux-init.sh &&
    . $UCONFDIR/script/htd/tmux-init.sh || error TODO 1
  test -n "$3" || {
    set -- "$@" "$(htd_uconf__tmux_init_cwd "$@")"
  }
  out=$(setup_tmpd)/htd-tmux-init-$$
  $tmux has-session -t "$1" >/dev/null 2>&1 && {
    logger "Session $1 exists"
    note "Session $1 exists"
  } || {
    $tmux new-session -dP -s "$1" "$2" && {
    #>/dev/null 2>&1 && {
      note "started new session '$1'"
      logger "started new session '$1'"
    } || {
      warn "Failed starting session '$1' ($?) ($out):"
      logger "Failed starting session '$1' ($?) ($out):"
      printf "Cat ($out) "
    }
    test ! -e "$out" || rm $out
  }
}


# Filter tmux sockets from lsof output, print field requested
htd_tmux_sockets() # Field
{
  test -n "$1" || set -- NAME
  {
    # list unix domain sockets
    lsof -U | grep '^tmux'
  } | {
      case "$1" in
      COMMAND ) awk '{print $1}' ;;
      PID ) awk '{print $2}' ;;
      USER ) awk '{print $3}' ;;
      FD ) awk '{print $4}' ;;
      TYPE ) awk '{print $5}' ;;
      DEVICE ) awk '{print $6}' ;;
      #NODE ) awk '{print $8}' ;;
      NAME )
          awk '{print $8}'
          awk '{print $9}'
        ;;
    esac
  } | sort -u
}


# Iterate tmux sockets and query for session list for each
htd_tmux_list_sessions() # Socket
{
  test -n "$1" || set -- $(htd_tmux_sockets)
  while test $# -gt 0
  do
    test -e "$1" && {
      note "Listing for '$1'"
      tmux -S "$1" list-sessions
    } || {
      warn "No such socket: '$1', skipped."
    }
    shift
  done
}


htd_tmux_session_list_windows() # Session [] [Output-Spec]
{
  test -n "$1" || set -- "$HTD_TMUX_DEFAULT_SESSION" "$2" "$3"
  test -n "$3" || set -- "$1" "$2" "#{window_name}"
  test -z "$4" || error "Surplus arguments '$4'" 1
  tmux_env_req 0
  $tmux list-windows -t "$1" -F "$3" | {
    case "$2" in
      "" )
          while read name
          do
            note "Window: $name"
          done
        ;;
      "-" ) cat ;;
      * )
          eval grep -q "'^$2$'"
        ;;
    esac
  }
}


htd_tmux_get()
{
  test -n "$1" || set -- "$HTD_TMUX_DEFAULT_SESSION" "$2" "$3"
  test -n "$2" || set -- "$1" "$HTD_TMUX_DEFAULT_WINDOW" "$3"
  test -n "$2" || set -- "$1" "$2" "$HTD_TMUX_DEFAULT_CMD"
  test -z "$4" || error "Surplus arguments '$4'" 1
  tmux_env_req 0

  # Look for running server with session name
  {
    test -e "$TMUX_SOCK" &&
      $tmux has-session -t "$1" >/dev/null 2>&1
  } && {
    info "Session '$1' exists"
    logger "Session '$1' exists"
    # See if window is there with session
    htd_tmux_session_list_windows "$1" "$2" && {
      info "Window '$2' exists with session '$1'"
      logger "Window '$2' exists with session '$1'"
    } || {
      $tmux new-window -t "$1" -n "$2" "$3"
      info "Created window '$2' with session '$1'"
      logger "Created window '$2' with session '$1'"
    }
  } || {
    # Else start server/session and with initial window
    eval $tmux new-session -d -s "$1" -n "$2" "$3" && {
      note "Started new session '$1'"
      logger "Started new session '$1'"
    } || {
      warn "Failed starting session '$1' ($?)"
      logger "Failed starting session '$1' ($?)"
    }
    # Copy env to new session
    for var in TMUX_SOCK $HTD_TMUX_ENV
    do
      $tmux set-environment -g $var "$(eval printf -- \"\$$var\")"
    done
  }
  test -n "$TMUX" || {
    note "Attaching to session '$1'"
    $tmux attach
  }
}


# Shortcut to create window, if not exists
# htd tmux-winit SESSION WINDOW DIR CMD
htd_tmux_winit()
{
  tmux_env_req 0
  ## Parse args
  test -n "$1" || error "Session <arg1> required" 1
  test -n "$2" || error "Window <arg2> required" 1
  # set window working dir
  test -e $UCONFDIR/script/htd/tmux-init.sh &&
    . $UCONFDIR/script/htd/tmux-init.sh || error TODO 1
  test -n "$3" || {
    set -- "$@" "$(htd_uconf__tmux_init_cwd "$@")"
  }
  test -d "$3" || error "Expected <arg3> to be directory '$3'" 1
  test -n "$4" || {
    # TODO: depending on context may also want to update or something different
    set -- "$1" "$2" "$3" "htd status"
  }
  $tmux list-sessions | grep -q '\<'$1'\>' || {
    error "No session '$1'" 1
  }
  $tmux list-windows -t $1 | grep -q $2 && {
    note "Window '$1:$2' already initialized"
  } || {
    $tmux new-window -t $1 -n $2
    $tmux send-keys -t $1:$2 "cd $3" enter "$4" enter
    note "Initialized '$1:$2' window"
  }
}


# Find a server with session name and CS env tag, and get a window
htd_tmux_cs()
{
  test -n "$1" || set -- Htd-$CS "$2" "$3"
  test -n "$2" || set -- "$1" 0    "$3"
  test -n "$3" || set -- "$1" "$2" ~/work
  (
    # TODO: hostname, session/socket tags
    export TMUX_SOCK_NAME=boreas-$1-term
    tmux_env_req 0
    htd_tmux_init "$1" "$SHELL" "$3"
    htd_tmux_winit "$@"
    $tmux set-environment -g CS $CS
    test -n "$TMUX" || $tmux attach
  )
}
