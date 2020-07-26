#!/usr/bin/env bash

mkvar_lib_load()
{
  true
}

mkvar_m='^\ *([A-Za-z_][A-Za-z_0-9]+)\ +([=:\?\-\+@%\*!]+)\ +(.*)\ *$'


# Translate mkvar to real Makefile where decorator assignments are used
mkvar_preproc()
{
  local lnr=0 
  while read line
  do
    lnr=$(( $lnr + 1 ))
    [[ "$line" =~ $mkvar_m ]] && {
      assign_deco="${BASH_REMATCH[2]}"

      mkvar_preproc_ "$assign_deco" "${BASH_REMATCH[1]}" "${BASH_REMATCH[3]}"
    }

    #echo "$line"
  done
}

mkvar_preproc_()
{
  #set -- "$1" "$2" "$(mkvar_shfmt_v "$3")"
  while test $# -gt 0
  do
    mkvar_preproc__ "$1" "$2" "$3"
    set -- "$1" "$2" "$__"
    test -n "$rest" && set -- "$rest" "$2" "\$($3)" || set -- "$rest" "$2" "$3"
  done
  #echo "2: $2"
  echo "$3"
}

mkvar_preproc__()
{
  case "$1" in

    '=' )   rest="$(echo "$1" | cut -c2-)"
            __="$(printf "$2 := $3")"
        ;;
    ':'* )  rest="$(echo "$1" | cut -c2-)"
            __="$(printf "simple $2, $3")"
        ;;
    '?'* )  rest="$(echo "$1" | cut -c2-)"
            test "$rest" = "=" && rest='' || error "Rest '$rest'" 1
            __="$(printf "$2 ?= $3")"
        ;;

    '++'* ) rest="$(echo "$1" | cut -c2-)"
            __="$(printf "prepend $2, $3")"
        ;;
    '+'* )  rest="$(echo "$1" | cut -c2-)"
            __="$(printf "append $2, $3")"
        ;;

    # XXX: second rx for char required.
    '%%'[a-z:.\0]* )  rest="$(echo "$1" | cut -c2-)"
            __="$(printf "prepend-w-char x, $2, $3")"
        ;;
    '%'[a-z:.\0]* )   rest="$(echo "$1" | cut -c2-)"
            __="$(printf "append-w-char x, $2, $3")"
        ;;
    '%%'* )  rest="$(echo "$1" | cut -c2-)"
            __="$(printf "prepend-w-char :, $2, $3")"
        ;;
    '%'* )   rest="$(echo "$1" | cut -c2-)"
            __="$(printf "append-w-char :, $2, $3")"
        ;;

    '!'* )   rest="$(echo "$1" | cut -c2-)"
        ;;
    '@'* )   rest="$(echo "$1" | cut -c2-)"
            __="$(printf "if-exists $2, $3")"
        ;;
    '*'* )   rest="$(echo "$1" | cut -c2-)"
            __="$(printf "if-glob $2, $3")"
        ;;

    * ) error "Unknown assignment modified '$1'" 1;;

  esac
}

    
mkvar_sh()
{
  local lnr=0 directive= args_rx_ref= args_arr=
  while read line
  do
    lnr=$(( $lnr + 1 ))
    [[ "$line" =~ ^\ *([^\ ]+)\ +([=:\?\-\+@%\*!]+)\ +(.*)\ *$ ]] && {
      assign_deco="${BASH_REMATCH[2]}"

      # mkvar_shfmt "$assign_deco" "${BASH_REMATCH[1]}" "${BASH_REMATCH[3]}"
      continue
    }

    echo "$line"
  done
}

mkvar_shfmt()
{
  $LOG note "mkvar:shftm" "Formatting to shell" "$2 $1 '${3}'"

  #set -- "$1" "$2" "$(mkvar_shfmt_v "$3")"
  while test $# -gt 0
  do
    set -- "$1" "$2" "$(mkvar_shfmt_a "$1" "$2" "$3")"
    test -n "$rest" &&
        set -- "$rest" "$2" "\$($3)" || set -- "$rest" "$2" "$3"
  done
  echo "2: $2"
  echo "$3"
}

# Prepare value for assignment
mkvar_shfmt_v()
{
  true
}

# Prepare assignment
mkvar_shfmt_a()
{
  case "$1" in

    '=' )    rest="$(echo "$1" | cut -c2-)"
            echo "expand $2 \"$3\""
        ;;
    ':'* )   rest="$(echo "$1" | cut -c2-)"
            echo "simple \"$3\""
        ;;
    '?'* )   rest="$(echo "$1" | cut -c2-)"
            echo "if-isset $2 \"$3\""
        ;;

    '++'* )  rest="$(echo "$1" | cut -c2-)"
            echo "prepend $2 '$3'"
        ;;
    '+'* )   rest="$(echo "$1" | cut -c2-)"
            echo "append $2 '$3'"
        ;;

    # XXX: second rx for char required.
    '%%'[a-z:.\0]* )  rest="$(echo "$1" | cut -c2-)"
            echo "prepend-w-char x $2 '$3'"
        ;;
    '%'[a-z:.\0]* )   rest="$(echo "$1" | cut -c2-)"
            echo "append-w-char x $2 '$3'"
        ;;
    '%%'* )  rest="$(echo "$1" | cut -c2-)"
            echo "prepend-w-char : $2 '$3'"
        ;;
    '%'* )   rest="$(echo "$1" | cut -c2-)"
            echo "append-w-char : $2 '$3'"
        ;;

    '!'* )   rest="$(echo "$1" | cut -c2-)"
        ;;
    '@'* )   rest="$(echo "$1" | cut -c2-)"
            echo "if-exists \"$3\""
        ;;
    '*'* )   rest="$(echo "$1" | cut -c2-)"
            echo "if-glob \"$3\""
        ;;

    * ) error "Unknown assignment modified '$1'" 1;;

  esac
}

#
