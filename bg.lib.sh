
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
  true "${bg_rund:=${XDG_RUNTIME_DIR:-/var/run/$(id -u)}/${SHELL_NAME:?}-bg}"
  true "${bg_fifo:=$bg_rund.fifo}"
  true "${bg_sock:=$bg_rund.sock}"
}

#bg_start ()
#{
#}

bg_open ()
{
  socat -u OPEN:/dev/null UNIX-CONNECT:$bg_sock
}

function setval ()
{
  #printf "declare -- %s=%q\n" "$1" "$(cat)"
  printf -v "$1" "%s" "$(cat)"
  declare -p "$1"
}

foo ()
{
  echo stdout1
  echo stderr1 >&2
  sleep 1
  echo stdout2
  echo stderr2 >&2
  return 123
}

bg_handle__load ()
{
  . "${1:?}"
  echo "$?" > "$bg_fifo"
}

bg_handle__eval ()
{
  rm -f stdout stderr
  mkfifo stdout stderr
  eval "${1:?}" >stdout 2>stderr &
  exec {fdout}<stdout {fderr}<stderr
  rc=$?
  stdout=$(cat <&$fdout)
  stderr=$(cat <&$fderr)
  {
    echo "$rc ${#stdout} ${#stderr}"
    test -z "${stdout:-}" || printf '%s' "$stdout"
    printf '\x1c'
    test -z "${stderr:-}" || printf '%s' "$stderr"
  } | tee -a "$bg_fifo"
  unset stdout stderr
}

bg_handle__bg_eval3 ()
{
  rm -f stdout stderr
  mkfifo stdout stderr
  eval "${1:?}" >stdout 2>stderr &
  pid=$!
  exec {fdout}<stdout {fderr}<stderr
  rm stdout stderr
  wait $pid
  rc=$?
  stdout=$(cat <&$fdout)
  stderr=$(cat <&$fderr)
  {
    echo "$rc ${#stdout} ${#stderr}"
    test -z "${stdout:-}" || printf '%s' "$stdout"
    printf '\x1c'
    test -z "${stderr:-}" || printf '%s' "$stderr"
  } | tee -a "$bg_fifo"
  unset stdout stderr

  exec {fdout}<&- {fderr}<&-
}

bg_handle__exit ()
{
  echo "Exiting $$..." >&2
  exit
}

bg_handle__reset ()
{
  echo "Resetting $$..." >&2
  exec $0 server1
}

# 'server' main loop for single-fifo, 1-to-1 line req/resp messaging
bg_recv_blocking ()
{
  local bg_fifo=${1:?}
  while true
  do
    echo "$0[$$]: recv: Waiting for data..." >&2
    # block until command data received
    read -r rq_h rq_r < "$bg_fifo"
    # handle request
    declare -f "bg_handle__${rq_h:-}" >/dev/null 2>&1 && {
        echo "Handling $rq_h '$rq_r" >&2
        bg_handle__${rq_h:?} "${rq_r:-}"
        echo "Handle $rq_h finished E${stat:-$?}" >&2
    } || {
        echo "? '$rq_h'" | tee -a "$bg_fifo"
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
