#!/usr/bin/env bash


notify_desktop()
{
  # FIXME: notify
  test "$uname" = "darwin" || return 0
  # NOTE: standalone osascript and macos user-preferences does not offer further
  # much usa notification toolkit
  # use,
  osascript \
      -e 'display notification "'"$3"'" with title "'"$1"'" subtitle "'"$2"'"'
}
