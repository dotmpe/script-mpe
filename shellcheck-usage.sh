#!/bin/sh

wiki () # ~ <SCREF> # Dump wikipage to text on stdout
{
  case "$1" in ( "CS"* ) set -- "$(echo "$1"|cut -c3-)" ;; esac

  #curl -L "https://www.shellcheck.net/wiki/$1" | elinks -dump

  curl -qSs "https://github.com/koalaman/shellcheck/wiki/SC$1" |
      bs-cli.py xpath '//*[@class="markdown-body"]' - |
      elinks -dump -no-references
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


# SC2162: read without -r will 'mangle' backslashes.
# -r doesnt really "mangle" anything, but I get the idea. No magic characters.
# But also no line-continuations.
#
# The exact reader type for generic functions cannot be predetermined, but can
# be one of several. Normally ${read:-read -r} suffices so that for specific
# needs an alt can be provided. See read-{asis,content,escaped} for the basic
# types.


shellcheck_usage_loadenv ()
{
  . "$US_BIN"/os-htd.lib.sh &&
  . "$US_BIN"/user-script.lib.sh
}


# Main entry (see user-script.sh for boilerplate)

test -n "${user_script_loaded:-}" || {
  . "${US_BIN:-"$HOME/bin"}"/user-script.sh
  unset SHELL
  user_script_shell_env
}

# Parse arguments
! script_isrunning "shellcheck-usage" .sh || {
  eval "set -- $(user_script_defarg "$@")"
}

# Execute argv and return
script_entry "shellcheck-usage" "$@"
#
