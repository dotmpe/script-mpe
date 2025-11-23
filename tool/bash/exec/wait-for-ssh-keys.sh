#!/usr/bin/env bash

while ! 2>/dev/null >&2 ssh-add -L
do
  echo "Waiting for SSH keys..."
  sleep 5
done

echo "SSH keys ready, starting '$*'"

"$@"
