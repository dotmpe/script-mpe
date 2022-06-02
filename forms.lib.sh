#!/bin/sh

### Interactive terminal util


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

# Bash has 'select' but I didn't like the UI much.
# Reads single char value into '$choice'.
#
# This clears the prompt-line after a correct choice is made, else
# it also clears but then prints an stderr line
# and then keeps asking again until a valid choice or interrupt.
#
# The options are embedded into the choice-string, and the language is
# hardcoded.
prompt_term_choice () # ~ <Choice-String>
{
  choices=$(echo "$1" | grep -Po '(?<=\[).(?=\])' | tr '\n' ' ')
  while true
  do
    read -n 1 -p "$1: " choice

    case " $choices " in
        ( *" $choice "* ) break ;; # Return OK
        ( * )
              # Clear promptline, print error response and re-try
              tput -S <<STDIN
el
el1
cub $(tput cols)
STDIN
              echo "$choice?" >&2
            ;;
    esac
  done
  tput -S <<STDIN
el
el1
cub $(tput cols)
STDIN
}

#
