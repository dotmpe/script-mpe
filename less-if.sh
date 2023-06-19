#!/usr/bin/env bash

## Less-if: execute pager even less, make it pretty

# The primary function of a pager is to prevent terminal clobber. Traditionally
# PAGER may be set to 'less' and a complex sequence of options, with the result
# that all output is paged and can be browsed in a temporary buffer.
# There is also the even less memory intensive 'more', for those who care.
# (While it solves flooding terminal buffers by giving user control over
# output, it still inlines everything again.)

# less-if is a script that skips paging if output is too small to care
# about, making use of programs that invoke PAGER more pleasant and streamlined.
# It also adds fancy 'bat' options when appropiate. And prevents recursion by
# checking with parent command. Handling the terminal paging itself is always
# done with PAGER_NORMAL, which defaults to less -R.

# To use, set either of these variable to the maximum number of lines to output
# in-line at the terminal:
#
#    UC_OUTPUT_LINES
#    USER_LINES
#
# If not supplied, the terminal height is used as cut-off. To make this adapt
# shell (somewhat) dynamically for other values, use PROMPT_COMMAND to update
# setting before every prompt. XXX: I wonder what VT's have some WM hook for
# this.

# FIXME: cat does not really prevent clobbering from ANSI, may want to add
# filter (fancy=false?) or reset to TERM defaults? at EOF or even each line
# end, depending on the data that is dumped.


set -euo pipefail

if_ok () { return; }
cat_page () { cat; echo "${NORMAL:-$(tput sgr0)}"; }
# TODO: switch maybe to other pager format (raw, ansi, plain)
cat_page_plain () { ansi_clean; echo; }
# Remove ANSI as best as possible in a single perl-regex
ansi_clean ()
{
  perl -e '
while (<>) {
  s/ \e[ #%()*+\-.\/]. |
    \r | # Remove extra carriage returns also
    (?:\e\[|\x9b) [ -?]* [@-~] | # CSI ... Cmd
    (?:\e\]|\x9d) .*? (?:\e\\|[\a\x9c]) | # OSC ... (ST|BEL)
    (?:\e[P^_]|[\x90\x9e\x9f]) .*? (?:\e\\|\x9c) | # (DCS|PM|APC) ... ST
    \e.|[\x80-\x9f] //xg;
    1 while s/[^\b][\b]//g;  # remove all non-backspace followed by backspace
  print;
}'
}

if_ok "${PAGER_NORMAL:=$(command -v less) -R}"

# Look at parent command-name and prevent recursion
PCMD=$(ps -o comm= $PPID)
test "${PCMD##*/}" != delta &&
test "${PCMD##*/}" != bat ||
  IF_PAGER="$PAGER_NORMAL"

test -n "${IF_PAGER:-}" || {
  # Choose default (fancy) pager or normal
  if_ok "${IF_PAGER:=$(command -v bat)}" ||
  if_ok "${IF_PAGER:=$(command -v batcat)}" ||
  if_ok "${IF_PAGER:=$PAGER_NORMAL}"
}

test -x "${IF_PAGER%% *}" || {
  echo expected pager exec at IF_PAGER: E$?: ${IF_PAGER:-(unset)} >&2
  exit 127
}


args=${@:-/dev/stdin}
#echo "bat-if pager reading (from) '$args'" >&2
data=$(<"$args")
test -z "$data" &&
    lines=0 ||
    lines=$(echo "$data" | wc -l)

# This is not set in non-interactive script ctx
true "${LINES:=$(tput lines)}"

# Set either USER_LINES or UC_OUTPUT_LINES in profile to page on more or less
# lines
maxlines=${USER_LINES:-${UC_OUTPUT_LINES:-${LINES:?}}}


case "${IF_PAGER##*/} " in

  ( "bat "* )
      test $maxlines -le $lines && {
        test ${v:-${verbosity:-3}} -lt 6 ||
          echo "bat-if read $lines lines, max inline output is $maxlines" >&2
        bat_opts=--paging=always\ --style=rule,numbers
      } || {
        # Display 'File: ... <EMPTY>' (without deco) even if there is no content
        # but only if quiet_empty=false (see below)
        test $lines -eq 0 &&
            bat_opts=--paging=never\ --style=plain ||
            bat_opts=--paging=never\ --style=grid,numbers
      }

      # Display 'File:' header for both paging and nonpaging if known, but
      # only if quiet_empty=false
      { ${quiet_empty:-true} || test $lines -gt 0
      } && test "$args" = /dev/stdin ||
          bat_opts=$bat_opts,header\ --file-name="$args"
      set -- $bat_opts
    ;;

  ( "less "* )
      test 0 -eq $lines && exit 100
      test $maxlines -le $lines || IF_PAGER=cat_page
    ;;
esac

printf '%s' "$data" | $IF_PAGER "$@"

# Id: script.mpe less-if [2023]
