
## Routines to do simple text-based IPC in shell

# The half-duplex line client/server


bg_lib__load ()
{
  lib_require us
}

bg_lib__init ()
{
  true "${BG_BASE:=${SHELL_NAME:?}-bg}"
  #bg_sock=$BG_RUNB.sock
  ! sys_debug -dev -debug -init ||
    $LOG notice "" "Initialized bg.lib" "$(sys_debug_tag)"
}


# Actions to run with 'server' (bg_recv_blocking routine)

bg_handle__cd ()
{
  eval "cd ${1:?}"
  echo "$?" > "$BG_FIFO"
}

bg_handle__eval ()
{
  eval "${1:?}"
  echo "$?" > "$BG_FIFO"
}

# respond with status, std{out,err} length and content separated by FS
# (ASCII file-separator) characters.
bg_handle__eval_run ()
{
  : "${*:?Command line expected}"
  outp=${BG_RUNB:?}.stdout errp=${BG_RUNB:?}.stderr statp=${BG_RUNB:?}.stdstat
  mkfifo "$outp" "$errp" "$statp"
  #eval set -- "${@:?}"
  # Blocks bc pipes have no readers yet
  eval "set +e; echo>$statp; ${*:?}; echo \$? >$statp" >"$outp" 2>"$errp" &
  # Attach readers to pipes and read data
  exec {fdout}<"$outp" {fderr}<"$errp" {fdstat}<"$statp"
  stdout=$(cat <&$fdout)
  stderr=$(cat <&$fderr)
  stdstat=$(cat <&$fdstat)
  # Response
  {
    #printf '\x1c' # ASCII FS
    printf '%i %i %i\x1c' "$stdstat" "${#stdout}" "${#stderr}"
    printf '%s\x1c' "${stdout:-}" "${stderr:-}"
  } >"${BG_FIFO:?}" # | tee -a "${BG_FIFO:?}"
  rm -f "$outp" "$errp" "$statp"
  exec {fdout}<&- {fderr}<&- {fdstat}<&-
  unset stdout stderr outp errp statp
}

bg_handle__exit ()
{
  echo "Exiting $$..." >&2
  return ${_E_break:-197}
}

bg_handle__load ()
{
  eval ". ${1:?}"
  echo "$?" > "$BG_FIFO"
}

bg_handle__ping ()
{
  echo "pong" > "$BG_FIFO"
}

bg_handle__rcnt () # ~ # Print restart-counter value
{
  echo $bg_rcnt > "$BG_FIFO"
}

bg_handle__reset ()
{
  stderr echo ""
  $LOG warn "$lk" "Resetting background process"
  : "$(( bg_rcnt++ ))"
  exec $bgscr server $bg_rcnt
}


bg_init ()
{
  test $# -eq 0 || BG_BASE=${1:?}
  # bg:run-base: to store pid and keep fifo, socket etc.
  BG_RUNB=${XDG_RUNTIME_DIR:-/var/run/$(id -u)}/${BG_BASE:?}
  BG_PID=$BG_RUNB.pid
  # XXX:
  true "${BG_FIFO:=$BG_RUNB.fifo}"
  BG_LABEL='User background service'
  : "${lk:="$BG_BASE:$0[$$]"}"
}


# Handlers for bg-simple client

bg__check () # ~ # Check instance is responding
{
  us_log_v_warn 6 # Use INFO level for output
  bg_proc__running || return
  test -p "${BG_FIFO:?}" && {
    $LOG info "$lk" "Named pipe exists" "$BG_FIFO"
    $LOG debug "$lk" "Contacting $BG_LABEL..." "cmd:ping"
    $bgctx cmd ping || return

    local answer
    { read -t0.01 answer <"$BG_FIFO" && test -n "${answer:-}"
    } && {
      $LOG note "$lk" "$BG_LABEL is responding"
    } || {
      $LOG warn "$lk" "Cannot contact $BG_LABEL" "E$?" $? || return
    }
  } ||
    $LOG error "$lk" "No named pipe for $BG_LABEL" "E$?:$BG_FIFO" $?
}

bg__files () # ~ # List run-files
{
  ls -la "$BG_RUNB"*
}

bg__help ()
{
  # XXX: dont have $0 added to ENV_SRC yet @User-Script
  set -- $ENV_SRC $0 $(for libp in $ENV_LIB
    do
      test "bg.lib.sh" = "${libp##*\/}" ||
        str_globmatch "$_" "*-bg.lib.sh" && echo "$libp"
    done )
  grep -h '^\(bg_\(_\|proc__\|handle__\)\)' "$@" | sort -d
  # compgen -A function | grep '^\(bg_proc__\|bg_handle__\)'
}

bg__list () # ~
{
  ps -C bash -opid=,command= | grep "bash .*$0.*" | grep -v 'bg[^ ]*\( list\)\?$'
}

# Run server: read command lines at BG_FIFO and invoke handler routine
bg__server () # ~ [<Restart-count>] # Start main loop
{
  bg_rcnt=${1:-0}

  test 0 -lt ${bg_rcnt:?} || {
    bg_fifo_create || return
  }

  # cant overr
  #trap '{ rm -v "$BG_RUNB"*; }' QUIT
  #trap 'bg_proc__clean' SIGQUIT
  trap 'bg_proc__clean $?; exit $_' EXIT
  #$LOG warn : "traps" "E$?:$(stderr trap)"

  $LOG notice "$lk" "Starting server" "$$, restart-count:$bg_rcnt"
  echo "$$" >| "$BG_PID"
  test ! -e "$BG_RUNB.ilock" ||
    bg__started || return
  bg_recv_blocking "$BG_FIFO"
  return ${hr:-0}
}

bg__started ()
{
  "${quiet:-true}" && set -- || set -- -v
  rm "$@" "$BG_RUNB.ilock"
}

bg__clean () # ~ # Delete run-files
{
  ! std_quiet bg_proc__running || {
    $LOG error "$lk" "Instance is running" $PID 1 || return
  }
  rm -v "$BG_RUNB"*
  #rm -v "$BG_FIFO"
}

bg_proc__cmd () # ~ # Write request to run command-line to named-pipe
{
  local cmd_handler=${1:?}; shift
  echo "${cmd_handler//-/_}" "${@@Q}" > "$BG_FIFO"
}

bg_proc__details () # ~ # List open files for instance
{
  lsof -p $PID
}

bg_proc__ps () # ~ # Print instance pid and command-line
{
  #PID=$(<$BG_PID) || return
  ps -q $PID -opid=,command=
}

bg_proc__kill () # ~ # Exit and cleanup
{
  kill -9 $PID &&
  bg__clean
}

bg_proc__pid () # ~ Print PID for instance
{
  echo $PID
}

bg_proc__pwd () # ~ # Retrieve PWD for instance using pwdx
{
  # Show current working directory
  pwdx $PID | sed "s/^$PID: //"
  #readlink /proc/$PID/cwd
}

bg_proc__read_response ()
{
  # Use echo around cat to add newline
  : "$(< "$BG_FIFO")"
  test -z "$_" || echo "$_"
}

bg_proc__read_std_response ()
{
  exec {myfd}<"$BG_FIFO"
  # Read three FS-separated fields from data at named pipe
  read -r -d $'\x1c' stat outlen errlen <&$myfd
  test 0 -eq $outlen || {
    read -N $outlen stdout <&$myfd
    echo "$stdout"
  }
  read -n 1 _ <&$myfd # Read FS sep
  test 0 -eq $errlen || {
    read -N $errlen stderr <&$myfd
    echo "$stderr" >&2
  }
  exec {myfd}<&-
  return $stat
}

bg_proc__reset () # ~ # Restart if main script was changed on-disk
{
  # XXX: Reset if source script was overwritten. With Bash, the server or
  # background instance will be reading from script at fd 255.
  # The '~' suffix indicates original file has been replaced or changed.
  main_script=$( lsof -p $PID | grep ' 255r ' | awk '{print $9}' )
  test -e "$main_script" && return
  #test "${main_script:...}" = "~" || return 0
  $bgctx cmd reset
}

bg_proc__run ()
{
  case "${1:?}" in
    cd | eval )
        bg_proc__cmd "${@:?}" && return $(bg_proc__read_response)
      ;;
    eval-run )
        bg_proc__cmd "${@:?}" && bg_proc__read_std_response || return
      ;;
    * )
        bg_proc__cmd "${@:?}"
      ;;
  esac
}

bg_proc__run_cmd () # ~ # Perform command and capture status/std{out,err} (in subshell)
{
  bg_proc__run eval-run "$@"
}

bg_proc__run_eval () # ~ # Evaluate command in instance root scope
{
  bg_proc__run eval "$@"
}

bg_proc__running () # ~ # Check that instance is running (with ps)
{
  test -s "$BG_PID" &&
  PID=$(<$BG_PID) || return
  if_ok "$(ps -q $PID -ocommand=)" ||
    #$LOG warn : "Failed getting command-line for proc Id" "E$?:$PID" $? ||
      return
  test -n "$_" && BG_CMD=$_
}


bg_proc__clean () # ~ #
{
  rm -v "$BG_RUNB"*
}


bg_proc__stop () # ~ # Exit instance
{
  $bgctx cmd exit #&& bg_proc__clean
}

bg_proc__tree () # ~ # Show instance sub-processes and ancestors
{
  pstree -alsp $PID
}


# 'server' main loop for single-fifo, synchronous (1-to-1 line req/resp) messaging
bg_recv_blocking ()
{
  local bg_fifo=${1:?} hr=0

  # echo 'v1' >| "$bg_fifo"
  while true
  do
    $LOG info "$lk:recv" "Waiting for data..."
    # block until command data received
    read -r rq_h rq_r < "$bg_fifo"
    # look for known action, handle request. Each hanlder writes back to
    # bg_fifo as needed.
    std_quiet declare -F "bg_handle__${rq_h:-}" && {
      $LOG info "$lk:recv" \
        "Handling command" "$rq_h${rq_r:+" '"}$rq_r${rq_r:+"'"}"
      bg_handle__${rq_h:?} "${rq_r:-}" || hr=$?
      $LOG debug "$lk:recv" "Handle $rq_h finished" "E${stat:-$?}"
      test $hr -eq 0 || break
    } || {
      echo "? '$rq_h'" | tee -a "$bg_fifo"
    }
  done
  return $hr
}

# Restarts the process, but keeps same PID (at least on Linux)
#bg_reload () # ~
#{
#  echo "Forking $0[$$] to new server process..." >&2
#  exec "$0" "${be_entry:-server}"
#}

# Old routine using domain socket where a proper multi-client server is running
#bg_writeread () # ~ <Cmd ...>
#{
#  printf -- "%s\r\n" "${*@Q}" |
#      socat -d - "UNIX-CONNECT:$bg_sock" 2>&1 |
#      tr "\r" " " | while read -r line
#  do
#    case "$line" in
#      *" OK " )
#          return
#        ;;
#      "? "* )
#          return 1
#        ;;
#      "!! "* )
#          error "$line"
#          return 1
#        ;;
#      "! "*": "* )
#          stat=$(echo $line | sed 's/.*://g')
#          return $stat
#        ;;
#    esac
#    echo "$line"
#  done
#}

#
