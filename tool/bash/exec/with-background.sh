#!/usr/bin/env bash
#
# with-background.sh
# Copyright (C) 2026 qwrt <qwrt@t460s>
#
# Distributed under terms of the MIT license.

[[ -t 0 && -t 1 && -t 2 ]] && {
  us-env -R us-env ||
    >&2 echo "E$? getting user base env (ignored)"

} || {
  set -euETo pipefail
  trap - SIGINT
  >&2 echo non-interactive OK
}

# Read arguments
track_cmd ()
{
  declare -ga "commands_$i"
  declare -n _cmd="commands_$i"
  _cmd=( "${cmd[@]}" )
  unset cmd
  ((i+=1))
}

i=0
while (($#))
do
  if [[ $1 == -- ]]; then track_cmd
  else
    [[ ${cmd[*]:+set} ]] || declare -a cmd
    cmd+=( "$1" )
  fi
  shift
done
[[ ! ${cmd[*]:+set} ]] || track_cmd

# Start commands
for (( j = 0; j < i; j++ ))
do
  # shellcheck disable=2178
  declare -n _cmd="commands_$j"
  [[ ${_cmd[*]: -1:1} == '&' ]] && {
    "${_cmd[@]: 0: ${#_cmd[*]}-1}" &
    commands[j]=$!
  } || {
    "${_cmd[@]}"
    commands[j]=$?
  }
done

# Switch to more appropiate mode for interactive session
set +ET

#
