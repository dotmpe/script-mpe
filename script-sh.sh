#!/bin/sh

script_sh_src=$_

set -e



# generates an 8 bit color table (256 colors) for
# reference purposes, using the \033[48;5;${val}m
# ANSI CSI+SGR (see "ANSI Code" on Wikipedia)
#
# Works with Bash, not sh. On a Linux.
# Somehow OSX (10.8.5) uses bash too and works except for dysfunctional echo..

script_sh__256colors()
{
  printf "\n   +  "
  for i in {0..35}; do
    printf "%2b " $i
  done

  printf "\n\n %3b  " 0
  for i in {0..15}; do
    printf "\033[48;5;${i}m  \033[m "
  done

  #for i in 16 52 88 124 160 196 232; do
  for i in {0..6}; do
    let "i = i*36 +16"
    printf "\n\n %3b  " $i
    for j in {0..35}; do
      let "val = i+j"
      printf "\033[48;5;${val}m  \033[m "
    done
  done

  printf "\n"
}


# Author: B. van Berkum
# Date: 2008-12-05

script_sh__16colors()
{
  {
    printf "\033[0;30mBlack\t0;30\033[0m\t\033[1;30mBoldBlack/DarkGray\t1;30\033[0m\n"
    printf "\033[0;34mBlue\t0;34\033[0m\t\033[1;34mBold/LightBlue\t1;34\033[0m\n"
    printf "\033[0;32mGreen\t0;32\033[0m\t\033[1;32mBold/LightGreen\t;32\033[0m\n"
    printf "\033[0;36mCyan\t0;36\033[0m\t\033[1;36mBold/LightCyan\t1;36\033[0m\n"
    printf "\033[0;31mRed\t0;31\033[0m\t\033[1;31mBold/LightRed\t1;31\033[0m\n"
    printf "\033[0;35mPurple\t0;35\033[0m\t\033[1;35mBold/LightPurple\t1;35\033[0m\n"
    printf "\033[0;33mBrown\t0;33\033[0m\t\033[1;33mYellow\t1;33\033[0m\n"
    printf "\033[0;37mLightGray\t0;37\033[0m\t\033[1;37mWhite\t1;37\033[0m\n"
  } | column -t
}


script_sh__16colors2()
{
  # prints a color table of 8bg * 8fg * 2 states (regular/bold)
  echo
  echo Table for 16-color terminal escape sequences.
  echo Replace ESC with \\033 in bash.
  echo
  echo "Background | Foreground colors"
  echo "---------------------------------------------------------------------"
  for((bg=40;bg<=47;bg++)); do
    for((bold=0;bold<=1;bold++)) do
      printf -- "\033[0m"" ESC[${bg}m   | "
      for((fg=30;fg<=37;fg++)); do
        if [ $bold == "0" ]; then
          printf -- "\033[${bg}m\033[${fg}m [${fg}m  "
        else
          printf -- "\033[${bg}m\033[1;${fg}m [1;${fg}m"
        fi
      done
      printf -- "\033[0m\n"
    done
    echo "--------------------------------------------------------------------- "
  done
  echo
}


  # tree: blue (34)
  # pid: yellow (33)
  # punctuation: grey
  # -options: purple
  # =values: green (32)

script_sh_spc__colorize_pstree='colorize-pstree [ -s SEARCH | -p PID ]'
script_sh__colorize_pstree()
{
  case "$(uname -s)" in

    Darwin )
        pstree "$@" > /tmp/pstree
        case "$@" in
            *-s" "* )
                str="$(echo "$@" | sed -E 's/^.*-s\ ([^\ ]+).*$/\1/')"
                word='s/'$str'/\\033[31m&\\033[0m/g'
                ;;
            *-p" "* )
                pid="$(echo "$@" | sed -E 's/^.*-p\ ([0-9]+).*$/\1/')"
                echo pid=$pid
                word='s/'$pid'/\\033[31m&\\033[0m/g'
                ;;
        esac
        echo "$(cat /tmp/pstree | sed -E '
s/^([\ [:punct:]]+)\ ([0-9]+)\ ([A-Za-z0-9_]+)/\\033[34m\1\ \\033[33m\2\ \\033[32m\3\ \\033[0m/g
          s/=([[:graph:]]+)/=\\033[0;32m\1\\033[0m/g
          s/\ -[^=\ ]+=?/\\033[0;35m&\\033[0m/g
          s/\.|\//\\033[1;30m&\\033[0m/g
        '$word' ')"

      ;;

    Linux )
        /usr/bin/pstree -U "$@" | sed '
          s/[-a-zA-Z]\+/\x1B[32m&\x1B[0m/g
          s/[{}]/\x1B[31m&\x1B[0m/g
          s/[─┬─├─└│]/\x1B[34m&\x1B[0m/g
        '
      ;;

  esac
}



# Generic subcmd's

script_sh_man_1__help="Echo a combined usage and command list. With argument, seek all sections for that ID. "
script_sh_spc__help='-h|help [ID]'
script_sh__help()
{
  (
    base=script_sh \
      choice_global=1 std__help "$@"
  )
}
script_sh_als___h=help


script_sh_man_1__version="Version info"
script_sh_spc__version="-V|version"
script_sh__version()
{
  echo "script-mpe:$scriptname/$version"
}
script_sh_als___V=version


script_sh_man_1__edit_main="Edit the main script file"
script_sh_spc__edit_main="-E|edit-main"
script_sh__edit_main()
{
  locate_name $scriptname || exit "Cannot find $scriptname"
  note "Invoking $EDITOR $fn"
  $EDITOR $fn
}
script_sh_als___E=edit-main



### Main


script_sh_main()
{
  local scriptpath="$(cd "$(dirname "$0")"; pwd -P)"
  script_sh_init || return $?

  local scriptname=script-sh base=$(basename "$0" .sh) verbosity=
  case "$base" in
    $scriptname )
        local \
          subcmd= failed= \
          subcmd_pref= subcmd_suf= \
          subcmd_func_pref=${base}__ subcmd_func_suf=

        test -n "$1" || set -- main-doc
        script_sh_lib "$@" || error script-sh-lib $?

        try_subcmd "$@" && {
          box_lib script-sh || error "box-src-lib script-sh" 1
          shift 1
          script_sh_load "$@" || error "script-sh-load" $?
          var_isset verbosity || local verbosity=5

          test -z "$arguments" -o ! -s "$arguments" || {
            info "Setting $(count_lines $arguments) args to '$subcmd' from IO"
            set -f; set -- $(cat $arguments | lines_to_words) ; set +f
          }

          $subcmd_func "$@" || r=$?
          script_sh_unload || r=$?
          exit $r
        }
      ;;
    * )
        error "not a frontend for $base ($scriptname)" 1
      ;;
  esac
}

# FIXME: Pre-bootstrap init
script_sh_init()
{
  test -z "$BOX_INIT" || return 1
  test -n "$scriptpath"
  export SCRIPTPATH=$scriptpath
  test -n "$SCRIPT_ETC" || SCRIPT_ETC="$scriptpath/etc"

  . $scriptpath/util.sh load-ext
  lib_load
  . $scriptpath/tools/sh/box.env.sh
  box_run_sh_test
  lib_load box

  #lib_load htd meta box date doc table disk remote ignores package
  # -- script-sh box init sentinel --
}


script_sh_lib()
{
  local __load_lib=1
  . $scriptpath/match.sh load-ext
  lib_load list ignores
  # -- script-sh box lib sentinel --
  set --
}


# Pre-exec: post subcmd-boostrap init
script_sh_load()
{
  test -n "$UCONFDIR" || UCONFDIR=$HOME/.conf/
  test -n "$INO_CONF" || INO_CONF=$UCONFDIR/script_sh
  test -n "$APP_DIR" || APP_DIR=/Applications

  hostname="$(hostname -s | tr 'A-Z.-' 'a-z__' | tr -s '_' '_' )"

  test -n "$EDITOR" || EDITOR=vim
  # -- script_sh box load sentinel --
  set --
}


# Post-exec: subcmd and script deinit
script_sh_unload()
{
  local unload_ret=0

  #for x in $(try_value "${subcmd}" "" run | sed 's/./&\ /g')
  #do case "$x" in
  # ....
  #    f )
  #        clean_failed || unload_ret=1
  #      ;;
  #esac; done

  clean_failed || unload_ret=$?

  env | grep -i 'meta'

  unset subcmd subcmd_pref \
          def_subcmd func_exists func \
          failed

  return $unload_ret
}




# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )
  # Ignore 'load-ext' sub-command
  test -z "$__load_lib" || set -- "load-ext"
  case "$1" in load-ext ) ;; * )
    script_sh_main "$@"
  ;; esac
;; esac

# Id: script-mpe/0.0.4-dev script-sh.sh
