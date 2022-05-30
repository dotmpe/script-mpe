#!/bin/sh

#shellcheck disable=SC1090 # follow non-constant source


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


# SC2162: read without -r will mangle backslashes.
# -r doesnt really "mangle" anything, but I get the idea. So instead
# of 'read' I use read_lines or read_asis to avoid warnings.


shellcheck_loadenv ()
{
  . "${US_BIN:-"$HOME/bin"}"/os-htd.lib.sh
}


test -n "${user_scripts_loaded:-}" ||{
  . "${US_BIN:-"$HOME/bin"}"/user-scripts.sh
  unset SHELL
  user_scripts_loadenv
}

! script_baseext=.sh script_isrunning "shellcheck-usage" ||
    eval "set -- $(user_script_defarg "$@")"

script_baseext=.sh \
script_defcmd="" \
    script_entry "shellcheck-usage" "$@"
#
