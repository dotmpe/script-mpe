#!/bin/sh

### Interactive terminal util

# Bash has 'select' but I didn't like the UI much.
# Also, if the terminal runs in a graphical DE nicer interfaces may be
# available.

# Using codes from tput a more elaborate TUI can be build
# FIXME: but need to verify what is supported for current terminal (terminfo)


is_desktop ()
{
  false # TODO: detect X session
}

do_desktop ()
{
  is_desktop && test "${USE_DESKTOP:-1}" = "1"
}

# XXX: depends on U-s:std.lib
do_terminal ()
{
  ! std_batch_mode
}

prompt_choice ()
{
  #shellcheck disable=2015
  do_desktop &&
    set -- prompt_dialog_choice "$@" || {
      do_terminal &&
        set -- prompt_term_choice "$@" || return 3
    }

  "$@"
}

prompt_dialog_choice ()
{
  false # TODO: do some gtk thing or motif maybe
}

prompt_clear_after ()
{
  tput -S <<STDIN
ed
STDIN
}

# Clear entire current line and start again at beginning again
# el, el1: clear to end and beginning of line
# cub <N>: move cursor <N> cols left
prompt_reset_line ()
{
  tput -S <<STDIN
el
el1
cub $(tput cols)
STDIN
}

# This reads single char value into '$choice' and validates input, and removes
# the prompt line from output.
#
# Uses tput to clean the prompt line once a correct choice is made, else
# it also clears but prints an stderr line, and then keeps prompting until
# a valid choice (or interrupt or other exit signal).
#
# The options are embedded into the choice-string. Having the prompt and choices
# on a single line is required here but may not be very readable, see
# prompt-term-choice-lines.
#
# Because the matching is fairly simple, this only extracts and matches
# verbatim, single character input values. More patterns of values to pass
# as well can be passed as additional arguments.
#
prompt_term_choice () # ~ <Prompt-choices-string> [<Pass-globs...>]
{
  choices=$(echo "$1" | grep -oP '(?<=\[).(?=\])' | tr '\n' ' ')
  while true
  do
    read -n 1 -p "$1: " choice

    case " $choices " in
        ( *" $choice "* ) break ;; # Return OK
        ( * )
            for glob in "${@:2}"
            do
              case "$choice" in ( $glob ) break ;; esac
            done

            prompt_reset_line
            echo "$choice?" >&2
          ;;
    esac
  done
  prompt_reset_line
}

# This expects one prompt line, separate from a menu of several option lines
# following it.
# Because the actual prompt is separate, it may as well be left in output
# followed by the entered value, to provide for a more consise log that way.
# (<prompt_clear=false>)
#
prompt_term_choice_lines () # ~ <Prompt-choices-lines>
{
  choices=$(echo "$1" | grep -oP '(?<=\[).(?=\])' | tr '\n' ' ')
  choices_lines=$(( $(echo "$1" | wc -l) - 1 ))
  prompt_line=${1%%$'\n'*}
  while true
  do
    read -n 1 -p "$1$(printf 'cuu %i\ncub %i\ncuf %i\n' \
      $choices_lines $(tput cols) ${#prompt_line} | tput -S )" choice

    case " $choices " in
        ( *" $choice "* ) break ;; # Return OK
        ( * )
            for glob in "${@:2}"
            do
              case "$choice" in ( $glob ) break 2 ;; esac
            done

            prompt_term_choice_lines_reset
            echo " ? " >&2
          ;;
    esac
  done
  prompt_term_choice_lines_reset
}

prompt_term_choice_lines_reset ()
{
  ${prompt_clear:-false} && {
    prompt_reset_line || return
  } || {
    prompt_clear_after
  }
}

#
