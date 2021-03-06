#!/bin/sh

. ~/bin/std.sh load-ext

# Testing daemonization of shell script, for no particular reason.
# Using netcat at Darwin works somewhat:

# $ daemonize.sh run
# $ daemonize.sh exec info

# But response is not written back (consistently),
# but sometimes the next run. Maybe experiment with multiple invocations,
# for simple 1-on-1 talk.

# setsid myscript.sh >/dev/null 2>&1 < /dev/null &

# ----


daemonize__info()
{
  note "Running at $$"
}

daemonize__edit()
{
  $EDITOR $0 "$@"
}

daemonize__clean()
{
  rm -f $sock
  rm -f $fifo
}

daemonize__exit()
{
  exit
}


daemonize__fork()
{
  trap process_USR1 SIGUSR1
  note "Fork $$: 0=$0 @$@"
  exec $0 child "$@" &
  return 0
}

daemonize__child()
{
  note "Child $$: 0=$0 @$@"
  case "$uname" in
    Darwin )
      setup_launchd_service
      start_launchd_service
      ;;
    Linux )
      umask 0
      exec setsid $0 spawn "$@" &
      #</dev/null >/dev/null 2>/dev/null &
      ;;
  esac
  return 0
}


process_USR1() {
  echo 'Got signal USR1'
  exit 0
}


# Exec cmd over websocket (server must be running)
daemonize__exec()
{
  note "Exec '$@'"
  ps aux | grep '\<nc\>' | grep -v grep

  #fifo_client=/tmp/client
  #test ! -e $fifo_client || rm $fifo_client
  #mkfifo $fifo_client
  #cat "$fifo_client" | nc -U $sock &

  #echo "$@" | nc -U $sock -

  echo "$@" | nc -i 1 -w 15 -U $sock -

  #| while read out
  #do
  #  note "Exec out='$out'"
  #done
  #echo "$@" >> $fifo_client
}

# Run without detaching, accept subcmd through domain socket
daemonize__run()
{
  daemonize__clean

  while true; do

    daemonize__spawn

  done
}

# XXX: trying nohup. Darwin. Redirects something so no output on fifo.
daemonize__nohup()
{
  #nohup daemonize__run &
  nohup daemonize.sh run &
}

daemonize__serve()
{
  echo
}

# Wait for and exec. one subcmd through websocket, using fifo to return output
daemonize__spawn()
{
  note "Spawn $$: 0=$0 @=$@"
  ps aux | grep $$ | grep -v grep

  #exec >/tmp/outfile
  #exec 2>/tmp/errfile
  #exec 0</dev/null
  r=

  #fifo3=/tmp/fifo3
  #fifo4=/tmp/fifo4
  #rm -rf $fifo3 $fifo4
  #mkfifo $fifo3 $fifo4
  ##exec 3> $fifo3
  ##4< $fifo4
  #nc -k -l -U $sock - < $fifo3 > $fifo4 &
  #cat $fifo4 | while read subcmd args
  #do
  #  daemonize__${subcmd}
  #  daemonize__${subcmd} "$args" 2>&1 > $fifo3
  #done
  #<&4

  mkfifo $fifo

  #buffer -i $fifo &

  cat $fifo | nc -k -l -U $sock - | while read subcmd args
  do
    #type daemonize__${subcmd} >/dev/null 2>/dev/null
    daemonize__${subcmd} "$args"
    #2>&1 > $fifo
    strace echo "OK $?" > $fifo &
    break
  done

  note "Cleaning after spawn"
  daemonize__clean

  return $r
}


# ----


# Main

daemonize__init()
{
  daemonize_init || return 0

  local scriptname=daemonize base=$(basename $0 .sh) verbosity=5 \
    scriptpath="$(dirname "$(realpath "$0")")"

  case "$base" in $scriptname )

    local subcmd_def= \
      subcmd_pref= subcmd_suf= \
      subcmd_func_pref=daemonize__ subcmd_func_suf=

      daemonize_lib

      # Execute
      main_run_subcmd "$@"
      ;;

    #* )
    #  error "not a frontend for $base"
    #  ;;
  esac
}

daemonize_init()
{
  test -z "$BOX_INIT" || return 1
  export SCRIPTPATH=$scriptpath
  . $scriptpath/tools/sh/box.env.sh
  . $scriptpath/util.sh
  box_run_sh_test
  lib_load main box darwin
  # -- daemonize box init sentinel --
}

daemonize_lib()
{
  . $scriptpath/match.sh load-ext
  # -- daemonize box lib sentinel --
  set --
}

daemonize_load()
{
  sock=/tmp/daemonize.sock
  fifo=/tmp/f

  # -- daemonize box load sentinel --
  set --
}

case "$0" in "" ) ;; "-*" ) ;; * )
  daemonize__init "$@"
      ;;
esac


