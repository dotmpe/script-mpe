#!/bin/sh

lib_load logger logger-std && {

  logger_std_init "stderr-console-logger T\$(date +%H:%M:%S)" &&
  export LOG=logger_stderr
}

# Sync: U-S:
