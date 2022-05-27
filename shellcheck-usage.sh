#!/bin/sh

# shellcheck disable=1090
. "$HOME"/bin/os-htd.lib.sh


wiki () # ~ <SCREF> # Dump wikipage to text on stdout
{
  echo "https://www.shellcheck.net/wiki/$1"
  return
  curl "https://www.shellcheck.net/wiki/$1" | elinks -dump
}


# SC2068: Double quote array expansions to avoid re-splitting elements.

# This is deceiving:

ex_quote_args ()
{
  set -- "$(echo "Line 1"; echo "Line 2"; echo "Line 3")"
  foreach "$@"
  echo argc:$#
}

# We actually do not set 3 arguments, but still the foreach results look like there are
#
# The only way to (re)set arguments in one line is to use eval.
# Otherwise we have to go over each argument, and have to do so without
# deferring to a function because that would get its own argv.


# SC2162: read without -r will mangle backslashes.
# -r doesnt really "mangle" anything, but I get the idea. So instead
# of 'read' I use read_lines or read_asis to avoid warnings.


test -n "${user_scripts_loaded:-}" || . ~/bin/user-scripts.sh
! script_baseext=.sh script_isrunning "shellcheck-usage" ||
    eval "set -- $(user_script_defarg "$@")"

script_baseext=.sh \
script_defcmd=check \
    script_entry "shellcheck-usage" "$@"
#
