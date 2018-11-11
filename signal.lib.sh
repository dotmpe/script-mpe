#!/bin/sh

signals_lib_load()
{
  # signals 1 to 31
  signal_names='HUP INT QUIT ILL TRAP ABRT EMT FPE KILL BUS SEGV SYS PIPE ALRM
TERM URG STOP TSTP CONT CHLD TTIN TTOU IO XCPU XFSZ VTALRM PROF WINCH INFO
USR1 USR2'
}

signals_init()
{
  trap signals_abort INT ABRT PIPE TERM
  #trap update_screen_width WINCH
}

signals_abort()
{
  kill -9 $$
}
