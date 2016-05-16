#!/bin/sh

# Start tmux session, then put this shell in a loop,
# monitoring session exists every 15 second. Used with OSX Global Daemon
# running as a specific user. The user socketname is still required for tmux
# to work correctly. Launchd handles keep alive, working directory, stdout/err,
# and loads the script on startup.

set -e

test -n "$sessionname" || sessionname=Simza
test -n "$socketname" || socketname=/opt/tmux-socket/tmux-$(id -u)/default


/usr/local/bin/tmux -S $socketname has-session -t $sessionname && {
  echo "Session $sessionname alreay exists"
} || {
  echo "Starting session $sessionname"
  /usr/local/bin/tmux -S $socketname new-session -d -s $sessionname bash
}

while
  /usr/local/bin/tmux -S $socketname has-session -t $sessionname
do
  echo "Session $sessionname ok"
  sleep 15
done

echo "Session $sessionname exited"

