
## Routines to do simple text-based IPC in shell

# The half-duplex line client/server may be interesting for keeping shared data
# (index, tables/trees) in a background process, or for mmultiple processes that
# can wait and signal to interact in turns. But to speed up other sorts of
# processing either single client or line-based messaging is not acceptable.
# But when using client-server to cut-down on startup time then starting new
# instances per connection defeats the whole purpose as well. Also this does
# not have asynchronous processing.


bg_lib_load ()
{
  true "${BG_RUND:=${XDG_RUNTIME_DIR:-/var/run/$(id -u)}/${SHELL_NAME:?}-bg}"
  true "${BG_FIFO:=$BG_RUND.fifo}"
  true "${bg_sock:=$BG_RUND.sock}"
}

#bg_start ()
#{
#}

bg_open ()
{
  socat -u OPEN:/dev/null UNIX-CONNECT:$bg_sock
}

bg_test_ioret ()
{
  echo stdout1
  echo stderr1 >&2
  sleep 1
  echo stdout2
  echo stderr2 >&2
  return 123
}


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

bg_handle__eval_run ()
{
  outp=${BG_RUND:?}.stdout errp=${BG_RUND:?}.stderr
  mkfifo "$outp" "$errp"
  eval "set -- ${1:?}"
  eval "${@:?}" >"$outp" 2>"$errp" &
  exec {fdout}<"$outp" {fderr}<"$errp"
  rc=$?
  stdout=$(cat <&$fdout)
  stderr=$(cat <&$fderr)
  {
    echo "$rc ${#stdout} ${#stderr}"
    test -z "${stdout:-}" || printf '%s' "$stdout"
    printf '\x1c' # ASCII FS
    test -z "${stderr:-}" || printf '%s' "$stderr"
  } | tee -a "${BG_FIFO:?}"
  rm -f "$outp" "$errp"
  exec {fdout}<&- {fderr}<&-
  unset stdout stderr outp errp
}

bg_handle__exit ()
{
  echo "Exiting $$..." >&2
  exit
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

bg_handle__reset ()
{
  echo "Resetting $$..." >&2
  exec $0 server 1
}


bg_proc__check ()
{
  test -p "${BG_FIFO:?}" && {
    echo "$0: Named pipe exists" >&2
    $0 bg-cmd ping || return

    local answer
    { read -t0.01 answer <"$BG_FIFO" && test -n "${answer:-}"
    } && {
      echo "$0: bg process is responding" >&2
    } || {
      echo "$0: Cannot contact bg" >&2
      #cat "$BG_FIFO"
      return 1
    }
  } ||
    echo "$0: No named pipe" >&2
}

bg_proc__pwd ()
{
  PID=$(<$BG_PID) || return
  # Show current working directory
  pwdx $PID | sed "s/^$PID: //"
  #readlink /proc/$PID/cwd
}

bg_proc__details ()
{
  PID=$(<$BG_PID) || return
  # List all sorts of file descriptor details for process
  lsof -p $PID
}

bg_proc__tree ()
{
  PID=$(<$BG_PID) || return
  pstree -alsp $PID
}

bg_proc__reset ()
{
  PID=$(<$BG_PID) || return
  main_script=$( lsof -p $PID | grep ' 255r ' | awk '{print $9}' )
  test -e "$main_script" && return
  # XXX: '~' suffix indicates original file has been replaced or when changed?
  $0 bg-cmd reset
}

# 'server' main loop for single-fifo, 1-to-1 line req/resp messaging
bg_recv_blocking ()
{
  local BG_FIFO=${1:?}
  while true
  do
    echo "$0[$$]: recv: Waiting for data..." >&2
    # block until command data received
    read -r rq_h rq_r < "$BG_FIFO"
    # handle request
    declare -f "bg_handle__${rq_h:-}" >/dev/null 2>&1 && {
        echo "Handling $rq_h${rq_r:+" '"}$rq_r${rq_r:+"'"}" >&2
        bg_handle__${rq_h:?} "${rq_r:-}"
        echo "Handle $rq_h finished E${stat:-$?}" >&2
    } || {
        echo "? '$rq_h'" | tee -a "$BG_FIFO"
    }
  done
  rm /tmp/buffer
}

# This restarts the process, but keeps same PID (at least on Linux)
bg_reload () # ~
{
  echo "Forking $0[$$] to new server process..." >&2
  exec "$0" "${be_entry:-server}"
}

# Old routine using domain socket where a proper multi-client server is running
bg_writeread () # ~ <Cmd ...>
{
  printf -- "%s\r\n" "${*@Q}" |
      socat -d - "UNIX-CONNECT:$bg_sock" 2>&1 |
      tr "\r" " " | while read line
  do
    case "$line" in
      *" OK " )
          return
        ;;
      "? "* )
          return 1
        ;;
      "!! "* )
          error "$line"
          return 1
        ;;
      "! "*": "* )
          stat=$(echo $line | sed 's/.*://g')
          return $stat
        ;;
    esac
    echo "$line"
  done
}

#
