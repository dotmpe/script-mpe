#!/bin/sh

# Terminal Multiplexer shell routines

tmux_lib_load()
{
  local upper=1
  # TODO: document where this was needded
  #which tmux 1>/dev/null || {
  #  export PATH=/usr/local/bin:$PATH
  #}

  default_env TMux-SDir /opt/tmux-socket
  # Set default env to differentiate tmux server sockets based on, this allows
  # distict CS env for tmux sessions
  default_env Htd-TMux-Env "hostname CS"
  # Initial session/window vars
  default_env Htd-TMux-Default-Session "Htd"
  default_env Htd-TMux-Default-Cmd "$SHELL"
  default_env Htd-TMux-Default-Window "$(basename $SHELL)"

  default_env TMux-Resurrect $HOME/.tmux/resurrect

  # default_env returns 1 to signal env var was already set
  true
}


tmux_env_req()
{
  test -n "$TMUX_SOCK" && {
    debug "Using TMux-Sock env '$TMUX_SOCK'"
  } || {
    test -n "$TMUX_SDIR" || error "TMUX socket dir env missing" 1
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
    test -d "$(dirname "$TMUX_SOCK")" || mkdir -vp "$(dirname "$TMUX_SOCK")"
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


# Filter tmux sockets from lsof -U output, print field requested or just the NAME
htd_tmux_sockets() # Field
{
  test -n "$1" || set -- NAME
  {
    # list unix domain sockets
    lsof -U | grep '^tmux'
  } | {

    # Print one column
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
          #awk '{print $9}'
        ;;
    esac
  } | sort -u
}

htd_tmux_socket_names()
{
  # Not sure what to make of ->(none) and ->0x<hfx> named-paths in lsof -U
  # (Darwin)
  htd_tmux_sockets NAME | grep -v '\ \(->0x\|->(none)\)'
}

# Iterate tmux sockets and query for session list for each
htd_tmux_list_sessions() # Socket
{
  test -n "$1" || set -- $(htd_tmux_socket_names)
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
          while read -r name
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
  test -n "$1" -a -n "$2" || error "at least two arguments expected" 1
  tmux_env_req 0
  test -n "$cwd" || cwd=$PWD

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
      $tmux new-window -c "$cwd" -t "$1" -n "$2" "$3"
      info "Created window '$2' with session '$1'"
      logger "Created window '$2' with session '$1'"
    }
  } || {
    test -d "$(dirname "$TMUX_SOCK")" || mkdir -vp "$(dirname "$TMUX_SOCK")"
    # Else start server/session and with initial window
    eval $tmux new-session -c "$cwd" -d -s "$1" -n "$2" "$3" && {
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

tmux_resurrect_list_raw()
{
  ls $TMUX_RESURRECT | grep '\.txt$'
}

tmux_resurrect_list()
{
  tmux_resurrect_list_raw | exts='.txt' pathnames
}

tmux_resurrect_lastname()
{
  readlink $TMUX_RESURRECT/last
}

# List panes for last session, with optional window filter. Print lines with
# Window-Name, Index, Title, PWD and Command. Title and/or Command may be empty.
# Multiple files are prefixed with filename, exact awk-print format or prefix
# behaviour is set through env.
tmux_resurrect_listpanes() # [window= awk_print_pane= prefix_name= opt_prefix=1] Dumpfile...
{
  test -n "$1" || set -- "last"
  test -e "$1" || set -- "$TMUX_RESURRECT/$1"

  test -n "$awk_print_pane" || {
      test -n "$opt_prefix" || opt_prefix=1
      test -n "$prefix_name" -o \( $opt_prefix -eq 1 -a $# -gt 1 \) &&
          awk_print_pane='FILENAME,$2,$3,$4,$8,$11' ||
          awk_print_pane='$2,$3,$4,$8,$11'
  }

  test -z "$window" && {
    awk '{if($1=="pane") print '"$awk_print_pane"';}' "$@" | tr -d ':'
  } || {
    awk '{if($1=="pane"&&$2=="'"$window"'") print '"$awk_print_pane"';}' "$@" | tr -d ':'
  }
}

# Get single list of window names, last session by default
tmux_resurrect_listwindows() # Dumpfile...
{
  test -n "$1" || set -- "last"
  test -e "$1" || set -- "$TMUX_RESURRECT/$1"
  test -n "$awk_print_win" || awk_print_win='$2'
  awk '{if($1=="window") print '"$awk_print_win"'}' "$@" | sort -u
}

# Get a single list of unique window names, from every recorded session.
# TODO: Cache result, update once a day
tmux_resurrect_allwindows()
{
  #test -n "$1" || set -- "$TMUX_RESURRECT/all-names.list"
  tmux_resurrect_listwindows \
      $( tmux_resurrect_list_raw | p="$TMUX_RESURRECT/" s= foreach_do )
}

# Line up window names for each dumpfile ever
tmux_resurrect_names()
{
  tmux_resurrect_list_raw | while read -r dumpfile
  do
    windows="$(tmux_resurrect_listwindows $dumpfile | lines_to_words)"
    printf "%32s %s\n" "$dumpfile" "$windows"
    continue
  done
}

# Line up counts per window for every session ever. XXX: works but takes hell of a time
tmux_resurrect_table()
{
  windows="$(tmux_resurrect_allwindows | lines_to_words)"
  echo "Dumpfile $windows"
  {
    tmux_resurrect_list

    tmux_resurrect_list_raw | while read -r dumpfile
    do
      for window in $windows
      do
        panes="$(window=$window tmux_resurrect_listpanes $dumpfile | count_lines)"
        echo "$panes"
        #printf "%-18s %9s %32s\n" "$window" "$panes" "$dumpfile"
      done
    done

  } | ziplists $(tmux_resurrect_list | count_lines)
}

# Characterise all recorded history (by Window names and numper of panes)
tmux_resurrect_info()
{
  test -n "$1" && {
      note "Panes for window '$1', every session ever"
      test -n "$2" && {
          window=$1 tmux_resurrect_listpanes "$2" | sort -u
      } || {
          window=$1 tmux_resurrect_listpanes \
              $( tmux_resurrect_list_raw | p="$TMUX_RESURRECT/" s= foreach_do ) |
              sort -u
      }
    } || {

      tmux_resurrect_table "$@"
    }
}

tmux_resurrect_panes() # Dumpfile
{
  test -n "$1" || set -- \
              $( tmux_resurrect_list_raw | p="$TMUX_RESURRECT/" s= foreach_do )
  awk_print_pane='$2,$4,$8,$11' tmux_resurrect_listpanes "$@" | sort -u
}

tmux_resurrect_drop() # [Dumpfile]
{
  test -n "$1" || set -- "last"
  test -e "$1" || set -- "$TMUX_RESURRECT/$1"
  test -e "$1" -a ! -h "$1" || set -- "$(readlink "$1")"
  test -e "$1" || set -- "$TMUX_RESURRECT/$1"

  test ! -e "$1" || rm -v "$1"
  tmux_resurrect_reset
}

tmux_resurrect_reset()
{
  rm "$TMUX_RESURRECT/last"
  local last=$(tmux_resurrect_list_raw | sort -rn | head -n 1)
  ln -s "$last" "$TMUX_RESURRECT/last"
}

# Move all dumpfiles except last one to backup, reformatting the filename
tmux_resurrect_backup_all()
{
  test -n "$cache" || cache="$TMUX_RESURRECT/all.list"
  (
    cd "$TMUX_RESURRECT"
    set -- $(tmux_resurrect_list_raw | sort -rn | tail +2 )
    p= s= act=tmux_resurrect_dumpfile_rename foreach_do "$@" |
    p='' archive_pairs "$@" |
    p='./' rsync_a=-iaL\ --remove-source-files rsync_pairs "$@"
  )
}

tmux_resurrect_dumpfile_rename()
{
  printf "$1" | sed \
's/tmux_resurrect_\([0-9]*\)-\([0-9]*\)-\([0-9]*\)T\([0-9]*\):\([0-9]*\):\([0-9]*\).txt/tmux_resurrect-\1_\2_\3-\4_\5_\6.txt/'
}

tmux_resurrect_backup_rename()
{
  printf "$1" | sed \
's/.*-tmux_resurrect-\([0-9]*\)_\([0-9]*\)_\([0-9]*\)-\([0-9]*\)_\([0-9]*\)_\([0-9]*\).txt/tmux_resurrect_\1-\2-\3T\4:\5:\6.txt/'
}

#
tmux_resurrect_restore() #
{
  set -- $(find $(realpath ~/htdocs/cabinet) \
      -iname '*tmux_resurrect-[0-9][0-9][0-9][0-9]_[0-9][0-9]_[0-9][0-9]-*')

  p= s= act=tmux_resurrect_backup_rename foreach_do "$@" |
    p="" to="$TMUX_RESURRECT/" rsync_a=-iaL rsync_pairs "$@"
  chmod ug+w "$TMUX_RESURRECT"/*.txt
}
