#!/bin/sh

## Key-value storage/service wrappers


status_lib__load ()
{
  # Status data should go into /var/lib but is only collected by user proc now.
  # Not sure if ~/.statusdir/{log,index,shell,cache} should stay in that
  # composition, probably not but it was the initial layout for statusdir.lib.
  # Index should be the new var-lib, log goes to var-log, and cache is var-cache
  # with some split into volatile RAM mounts and some syncronized.

  # XXX: I don't like local for this purpose, but dislike ~/.statusdir and
  # everthing hidden in home as well. And ~/.local/{bin,include,lib,share} is
  # usually already there, so using that for /var/lib type content in user home.
  : "${status_dirs:=$(echo {,.}meta/stat {$HOME/.local/var,/var/{lib,local}}/statusdir)}"

  # Above is expanded on echo before assignment and can be used for contexts
  # that do not care about nesting, however for nesting and additional local
  # dirs see status-dirs function.

  # TODO: remove index from stat{,userdir}/index path when log, cache is
  # moved to var-{log,cache} and other meta to /var/{run,backups}.
}

status_lib__init ()
{
  test -z "${status_lib_init:-}" || return $_
  true #lib_require
}


# Take relative paths from status-dir env var and look for them at every
# path-context.
status_dirs ()
{
  echo {,.}meta/{stat,tab} {$HOME/.local/var,/var/{lib,local}}/statusdir
}

status_key () # ~
{
  false
}

status_key_globalize ()
{
  echo "$hostname.$username.$1"
}

#
