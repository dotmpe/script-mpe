#!/usr/bin/env bash

## Less-if: execute pager even less, make it pretty

# The primary function of a pager is to prevent terminal clobber. Traditionally
# PAGER may be set to 'less' and a complex sequence of options, with the result
# that all output is paged and can be browsed in a temporary buffer. And there
# is the even less memory intensive 'more' for those who care, but while that
# solves flooding terminal buffers and gives the user control over output,
# it still inlines everything again.

# less-if is a script that skips paging if output is too small to care about,
# making use of programs that invoke PAGER more pleasant and streamlined. It
# still adds fancy 'bat' options when appropiate. And also it assumes Git's
# fancy paging is done by Delta, that uses Bat themeing and handles layout as
# well so then less-if invokes less or cat instead of bat.

# To use, set either of these variable to the maximum number of lines to output
# in-line at the terminal:
#
#    UC_OUTPUT_LINES
#    USER_LINES
#
# If not supplied, the terminal height is used as cut-off. To make this adapt
# shell (somewhat) dynamically, use PROMPT_COMMAND to update setting before
# every prompt. XXX: I wonder what VT's have some WM hook for this.


set -euo pipefail

if_ok () { return; }

test -n "${IF_PAGER:-}" || {
  if_ok "${IF_PAGER:=$(command -v bat)}" ||
  if_ok "${IF_PAGER:=$(command -v less)}"
}

# When Git invokes $PAGER, assume core.pager=delta and use less to page already
# fancied up output. Set IF_PAGER_GIT to overrule.
# Alternative is to put something like DELTA_PAGER=less in env profile but that
# bypasses page-if completely.
test -z "${GIT_EXEC_PATH:-}" || IF_PAGER="${IF_PAGER_GIT:-$(command -v less) -R}"

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
      test $maxlines -le $lines || IF_PAGER=cat
    ;;
esac

printf %s "$data" | $IF_PAGER "$@"
#
