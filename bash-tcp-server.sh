#!/bin/bash

# Example using Bash coproc and BSD netcat

# XXX: this does either print the date and then block, waiting even while
# stdin reached EOF, or on second case it just exits.

# $ bash-tcp-server <host=localhost> <port=3000> &
# $ echo d | nc -N localhost 3000
# $ echo q | nc -N localhost 3000

set -euo pipefail

coproc nc -l ${1:-localhost} ${2:-3000}

while true; do
  read -r cmd || {
    echo "Read aborted E$?" >&2
    break
  }
  case $cmd in
    d) date ;;
    q) break ;;
    *) echo 'What?'
  esac
done <&"${COPROC[0]}" >&"${COPROC[1]}"

test -z "${COPROC_PID:-}" && {
	echo Lost connection
} ||
	kill "$COPROC_PID"
