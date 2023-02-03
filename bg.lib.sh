
## Routines to do simple text-based IPC in shell

# The half-duplex line client/server may be interesting for keeping shared data
# (index, tables/trees) in a background process, or for mmultiple processes that
# can wait and signal to interact in turns. But to speed up other sorts of
# processing either single client or line-based messaging is not acceptable.
# But when using client-server to cut-down on startup time then starting new
# instances per connection defeats the whole purpose as well. Also this does
# not have asynchronous processing.


#bg_start ()
#{
#}

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

bg_reload () # ~
{
  echo "Forking $$ to new server process" >&2
  exec "$0" "${be_entry:-server}"
}

# 'server' main loop for single-fifo, 1-to-1 line req/resp messaging
bg_recv_blocking ()
{
  local bg_sock=${1:?}
  while true
  do
    echo "$0[$$]: Waiting for data..." >&2
    # block until data received
    read -r req < "$bg_sock"
    case "$req" in

        # simple interpreter, essentially opens up user shell session on socket
        # and needs some response type parsing
        "run "*)
            echo "Executing '${req/run }'"
            eval "${req/run }" >| /tmp/buffer
            stat=$?
            echo "Done E$stat"
            {
              cat /tmp/buffer
              echo "# Done E$stat"
            } > "$bg_sock";
            continue ;;
        r|reload ) bg_reload ;;
        q|quit ) return ;;
    esac
    # respond, block until client has read response
    echo "Data: '$req' (${#req})" | tee "$bg_sock"
  done
  rm /tmp/buffer
}

bg_open ()
{
  socat -u OPEN:/dev/null UNIX-CONNECT:$bg_sock
}

#
