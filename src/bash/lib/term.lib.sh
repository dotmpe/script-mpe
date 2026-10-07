#!/bin/sh

### term.lib: Helper for ANSI terminals (rather mostly Xterm-compat)

# XXX: see also sys, os, std, forms.
#
# I'm using rxvt-unicode (urxvt) which is derived from Xterm.
#
# The initial functions for this are OSC related, ie. 'ESC]'
# (Not to be confused with CSI or 'ESC[' escapes used to set
# color etc. in output strings.)
# OSC was mostly defined by Xterm but is supported by many terminals.
# This works for me with xterm, urxvt, kitty and gnome-terminal.
# Parameters are ;-separated.
# String terminator (ANSI-ST) can be both BEL or the standard ESC+'\'.
#
# For a (pretty exhaustive) document on control sequences (aka ANSI escapes) in
# Xterm see document, notably the section on OSC
# <https://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h3-Operating-System-Commands

# term_lib__load ()
#{
ESC="\033"
BEL="\007"
ANSI_ST="\033"'\'

case "$TERM" in
    ( "xterm-kitty"* )
TERM_RES="background foreground cursor highlight" ;;

    ( "rxvt"* )
TERM_RES="background foreground cursor mouse_background mouse"\
"_foreground highlight border" ;;

    ( "xterm"* )
        test -n "${GNOME_TERMINAL_SCREEN-}" && {
TERM_RES="background foreground cursor highlight"

        } || {
TERM_RES="background foreground cursor mouse_background mouse"\
"_foreground highlight"
        } ;;

    ( * )
TERM_RES="background foreground cursor highlight"
        echo "Unknown TERM, minimal TERM_RES set <$TERM>" >&2
      ;;
esac
TERM_RES=$TERM_RES\
" color0 color1 color2 color3 color4 color5 color6 color7"\
" color8 color9 color10 color11 color12 color13 color14 color15"
#}

# Query or set terminal OSC by name:
# - color[0-15]
# - foreground, background
# - mouse_{foreground,background}
# - cursor, highlight and border
#
# In query mode, multiple values can be fetched but the terminal settings
# are changed to read the results.
#
# With many subsequent queries in short time, everiy now and then one or
# two values are delayed for longer than the standard 10ns.
# In those cases adding a retry was far more efficient than raising the
# delay (at 0.01s it still occasionally missed values).
# At term_resource_retries=4 I have not seen missing values (the setting
# applied to the entire loop, not individual calls).
#
# Flags (for query mode):
#  f 0 Print :-separated fields (only with h=1), if set instead
#    print =-separated fields (with no space).
#  p 1 Parse rgb*:* to 24-bit hex notation
#  h 1 Include field name in output.
#  k 0 Keep-going after failure. Note: current impl. uses up retries
#    first.
#
#shellcheck disable=2015,2154
term_resource ()
{
  test -n "${2-}" && {
    case "$1" in
      ( name )             term_send_osc 0 "$2" ;;
      ( iconname )         term_send_osc 1 "$2" ;;
      ( title )            term_send_osc 2 "$2" ;;
      ( property )         term_send_osc 3 "$2" ;;

      ( color* )           term_send_osc 4 "${1#color}" "$2" ;;
      ( foreground )       term_send_osc 10 "$2" ;;
      ( background )       term_send_osc 11 "$2" ;;
      ( cursor )           term_send_osc 12 "$2" ;;
      ( mouse_foreground ) term_send_osc 13 "$2" ;;
      ( mouse_background ) term_send_osc 14 "$2" ;;
      ( highlight )        term_send_osc 17 "$2" ;;
      ( border )           term_send_osc 708 "$2" ;;

      ( pixbuf )           term_send_osc 20 "$2" ;;

      ( * )                return 64 ;;
    esac
  } || {
    #shellcheck disable=2086
    test $# -gt 0 || set -- $TERM_RES
    test -z "${term_resource_RET-}" || unset term_resource_RET
    test $# -gt 1 &&
      fun_flags term_resource k hfp ||
      fun_flags term_resource kh fp

    #shellcheck disable=2086 # No quotes for fun-flag variables
    #shellcheck disable=2004 # Arith. uses $/${}
    { term_query_init

      while test $# -gt 0
      do
        case "$1" in
          ( color* )           term_send_osc 4 "${1#color}" "?" ;;
          ( foreground )       term_send_osc 10 "?" ;;
          ( background )       term_send_osc 11 "?" ;;
          ( cursor )           term_send_osc 12 "?" ;;
          ( mouse_foreground ) term_send_osc 13 "?" ;;
          ( mouse_background ) term_send_osc 14 "?" ;;
          ( highlight )        term_send_osc 17 "?" ;;
          ( pixbuf )           term_send_osc 20 "?" ;;
          ( locale )           term_send_osc 701 "?" ;;
          ( version )          term_send_osc 702 "?" ;;
          ( tintcolor )        term_send_osc 705 "?" ;;
          ( border )           term_send_osc 708 "?" ;;

          ( * )                return 64 ;;
        esac || term_resource_RET=$?

        v=$(term_query_response)

        test -n "$v" -a -z "${term_resource_RET-}" || {
          : ${term_resource_RET:=$?}
          test ${term_resource_retries:-0} -gt 0 && {
            term_resource_retries=$(( $term_resource_retries - 1 ))
            term_resource_RET=
            continue
          }
          echo "Failed($term_resource_RET) getting '$1'" >&2
          test $term_resource_k = 0 && break || {
            shift; continue
          }
        }

        test $term_resource_p = 0 || {

          fnmatch "*;*" "$v" && {
            v=$(echo "$v" | cut -d ';' --output-delimiter ';' -f2- )
          }

          fnmatch "rgb*" "$v" && v=#$(term_resource_rgbhex "$v")
        }

        test $term_resource_h = 1 && {
          test $term_resource_f = 1 && {
            echo "$1: $v"
          } || {
            echo "$1=$v"
          }
        } || {
          echo "$v"
        }

        shift
      done

      term_query_deinit

      return ${term_resource_RET-}

    # Add carriage-returns lost with change of terminal mode
    } | sed 's/$/\r/g'
  }
}

term_load_resources ()
{
  for reskey in $TERM_RES
  do
    v="$(eval "echo \"\$$reskey\"")"
    test -n "$v" || {
      echo "Missing setting '$reskey' for terminal" >&2
      continue
    }
    term_resource "$reskey" "$v"
  done
  unset reskey v
}

# No idea about the format but this parses it to regular 24-Bit RGB
# hex notation.
term_resource_rgbhex ()
{
  case "$1" in
      ( "rgba:"* ) echo "$1" | cut -c6-7,11-12,16-17 ;;
      ( "rgb:"* ) echo "$1" | cut -c5-6,10-11,15-16 ;;
      ( * ) return 64 ;;
  esac
}

term_query_init ()
{
  { test -n "${GNOME_TERMINAL_SCREEN-}" ||
    fnmatch "xterm-kitty*" "$TERM"
  } && STTY_TIMEOUT=1

  term_query_oldstty=$(stty -g)

  # Set terminal to raw, minimal character read to 0
  # Set STTY_TIMEOUT n For time-out at n/10th seconds
  # (makes it work in some terminals).
  # Otherwise no time-out is set (on printf?), it just delays read a bit
  # but only for 10ns. Can be set to other values using TTY_RDELAY
  # (seconds).
  stty raw -echo min 0 time ${STTY_TIMEOUT:-0}
}

term_query_deinit ()
{
  stty $term_query_oldstty
  unset term_query_oldstty
}

term_query_response ()
{
  # Wait 10ns before reading if TTY time-out was set to zero.
  test ${STTY_TIMEOUT:-0} -eq 0 && sleep ${TTY_RDELAY:-0.00000001}

  read -r term_query_answer || {
    #echo "ERR$?" >&2
    true # XXX: Does this always return 1, why.
  }
  test -n "$term_query_answer" || term_query_RET=1

  # Strip common response escapes
  printf "$term_query_answer" | sed '
        s/'"$(echo "$ESC")"'\]//g
        s/'"$(echo "$ESC")"'\\//g
        s/'"$(echo "$BEL")"'//g
    '
  #      s/'"$(echo "$ESC")"'.//g
  #      s/'"$(echo "$ESC")"'\]\?//g
  #      s/'"$(echo "$ESC")"'\][0-9]*;//

  unset term_query_answer
}

# Output OSC query and read terminal response. Wrap while in TMUX.
# Strip response escape codes and echo result.
# Default is P1=11 for background color and P2=? for single-parameter
# queries. Add '?' for queries with more parameters.
term_oscmd () # ~ [(<P1>) [<Px...>]] # Do OSC query or operation on terminal
{
  test $# -gt 0 || {
    set -- 11
    test $# -gt 1 || set -- "$@" "?"
  }
  test -n "$1" || return 64
  test -z "${term_query_RET-}" || unset term_query_RET

  { term_query_init && term_send_osc "$@"
  } || { term_query_RET=$?
    term_query_deinit
    return $term_query_RET
  }

  term_query_response
  term_query_deinit

  return ${term_query_RET-}
}

# XXX: This was all copied from others and tested to work, but I have not
# checked it against ANSI, or term source codes etc.
#
#shellcheck disable=1003,2015,2059
term_send_osc () # ~ <P1> [<Px...>]
{
  osc_dlm=${ANSI_PS:-;}
  osc_end=${ANSI_ST:-$BEL}

  set -- "${ESC}]$(
        printf "%s$osc_dlm" "$@"|sed 's/'$osc_dlm'$//'
    )$osc_end"

  {
    test -n "${TMUX:-}" && {
      printf "${ESC}Ptmux$osc_dlm${ESC}$1${ESC}"'\'
    } || {
      printf "$1"
    }
  } >"${TTY:-/dev/tty}"

  unset osc_dlm osc_end
}

#
