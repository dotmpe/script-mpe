#!/usr/bin/env bash

# TODO: script for use with incron

set -euo pipefail

set -x

CWD=/srv/project-local/x-google-chrome-plugins/native-messaging-host
__load=ext . $CWD/cy-chrome-main.sh
#true "${CWD:="$(dirname "$0")"}"

# Get metadata from browser and write to FS
set_metadata() # File
{
  echo '{"name":"get-downloads","query":{"filename":"'"$1"'"}}' >> "$in_fifo"
  # client_write "get-downloads"

  # wait for response
  while test ! -e "$out_fifo"
  do sleep 0.1
  done

  client_read
  test ${compact-0} -eq 1 && {
    echo "$msg" | jq -c
  } || {
    echo "$msg" | jq
  }
}

list_metadata() #
{
  find ~/Downloads/ -type f | while read fn
  do
    set_metadata "$fn"
  done
}

$@
# get_download "$1"

#
