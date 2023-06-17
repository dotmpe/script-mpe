#!/bin/sh

### std.lib: logging and dealing with the shell's stdio decriptors


std_ht_lib__load ()
{
  true
}

std_ht_lib__init ()
{
  test "${std_ht_lib_init-}" = "0" && return
  test -n "$INIT_LOG" || return 102
  $INIT_LOG info "" "Done std-ht"
}

io_dev_path()
{
  case "$uname" in
    Linux ) echo /proc/$$/fd ;;
    Darwin ) echo /dev/fd ;;
    * ) error "io_dev_path $uname" 1
  esac
}

list_io_nums()
{
  return 1

  test -n "$1" \| set -- $$

  # XXX: other IO's may be presetn, like 255? pipe-sort removes it.
  case "$uname" in

    Linux )
        basenames /proc/$1/fd/*
      ;;

    Darwin )
        basenames /dev/fd/*
      ;;

  esac | sort -n
}

_stdio_type()
{
  test -n "$*" || return
  test -t 1 && echo t || {
    stdio_dev 1
    test -p $dev && echo p || {
      # other redirection.. file?
      test -f "$(readlink $dev)" && echo f || echo s
    }
  }
}


# http://www.etalabs.net/sh_tricks.html
#echo()
#(
#  fmt=%s end=\\n IFS=" "
#
#  while [ $# -gt 1 ] ; do
#    case "$1" in
#      [!-]*|-*[!ne]*) break ;;
#      *ne*|*en*) fmt=%b end= ;;
#      *n*) end= ;;
#      *e*) fmt=%b ;;
#    esac
#    shift
#  done
#
#  printf "$fmt$end" "$*"
#)

#echo()
#(
#  while [ $# -gt 1 ] ; do
#    case "$1" in
#      '-ne'|'-en') fmt="%b" end= ;;
#      '-n') end= ;;
#      '-e') fmt="%b" ;;
#    esac
#    shift
#  done
#  printf "$fmt$end" "$*"
#}



# check if stdout is a terminal...
#if [ -t 1 ]; then

#  # see if it supports colors...
#  echo="echo"
#  case $TERM in
#
#    *256color )
#        LOG_TERM=256
#        ncolors=$(tput colors)
#        # FIXME echo -e something going on with BSD sh?
#        echo="echo -e"
#      ;;
#
#    xterm* | ansi | linux )
#        LOG_TERM=16
#        ncolors=$(tput -T xterm colors)
#      ;;
#
#    screen )
#        LOG_TERM=16
#        ncolors=$(tput colors)
#      ;;
#
#    dumb | '' )
#        LOG_TERM=bw
#      ;;
#
#    * )
#        LOG_TERM=bw
#        echo "[std.sh] Other term: '$TERM'" >&2
#      ;;
#
#  esac
#
#  if test -n "$ncolors" && test $ncolors -ge 8; then
#
#    test -z "$debug" || echo "ncolors=$ncolors" >&2
#
#    bld="$(tput bold)"
#    underline="$(tput smul)"
#    standout="$(tput smso)"
#
#    norm="$(tput sgr0)"
#
#    test -n "$verbosity" && {
#      test $verbosity -ge 7 &&
#        echo "[$base:$subcmd:std.lib] ${drgrey}colors: ${grey}$ncolors${norm}" >&2
#    }
#
#    if test $ncolors -ge 256; then
#      #blackb="\e[0;90m"
#      #grey="\e[0;37m"
#      prpl="\033[38;5;135m"
#      blue="\033[38;5;27m"
#      red="\033[38;5;196m"
#      dylw="\033[38;5;208m"
#      ylw="\033[38;5;220m"
#      #norm="\033[0m"
#
#      test "$CS" = 'dark' && {
#        default="\033[38;5;254m"
#        bdefault="\033[38;5;231m"
#        grey="\033[38;5;244m"
#        dgrey="\033[38;5;238m"
#        drgrey="\033[38;5;232m"
#      }
#      test "$CS" = 'light' && {
#        default="\033[38;5;240m"
#        bdefault="\033[38;5;232m"
#        grey="\033[38;5;245m"
#        dgrey="\033[38;5;250m"
#        drgrey="\033[38;5;255m"
#      }
#
#      grn="$(tput setaf 2)"
#
#    else
#
#      grey=${default}
#
#      black="$(tput setaf 0)"
#      red="$(tput setaf 1)"
#      grn="$(tput setaf 2)"
#      ylw="$(tput setaf 3)"
#      blue="$(tput setaf 4)"
#      prpl="$(tput setaf 5)" # magenta
#      cyan="$(tput setaf 6)"
#      default="$(tput setaf 7)"
#      bdefault=${bld}${default}
#    fi
#  fi
##fi


# std-v <level>
# if verbosity is defined, return non-zero if <level> is below verbosity treshold
#std_v()
#{
#  test -z "$verbosity" && return || {
#    test $verbosity -ge $1 && return || return 1
#  }
#}
#
#std_exit()
#{
#  test -z "$2" || {
#    echo "std-exit: Surplus arguments '$2'" >&2
#    exit 200
#  }
#  test "$1" != "0" -a -z "$1" && return 1 || {
#    test -z "$verbosity" -a $verbosity -ge 5 &&
#      echo "std-exit $3" >&2
#    exit $1
#  }
#}
#
#emerg() { std_emerg "$@"; }
#crit() { std_crit "$@"; }
#error() { std_error "$@"; }
#warn() { std_warn "$@"; }
#note() { std_note "$@"; }
#debug() { std_debug "$@"; }
#
#std_emerg()
#{
#  std_v 1 || std_exit $2 || return 0
#  stderr "Emerg" "$1" $2
#}
#std_crit()
#{
#  std_v 2 || std_exit $2 || return 0
#  stderr "Crit" "$1" $2
#}
#std_error()
#{
#  std_v 3 || std_exit $2 || return 0
#  stderr "Error" "$1" $2
#}
#std_warn()
#{
#  std_v 4 || std_exit $2 || return 0
#  stderr "Warning" "$1" $2
#}
#std_note()
#{
#  std_v 5 || std_exit $2 || return 0
#  stderr "Notice" "$1" $2
#}
#std_info()
#{
#  std_v 6 || std_exit $2 || return 0
#  stderr "Info" "$1" $2
#}
#std_debug()
#{
#  std_v 7 || std_exit $2 || return 0
#  stderr "Debug" "$1" $2
#}

# demonstrate log levels
std_demo()
{
  return 1

  scriptname=std cmd=demo
  echo
  log "Log line"
  error "Foo bar"
  warn "Foo bar"
  note "Foo bar"
  std_info "Foo bar"
  debug "Foo bar"
  echo
  stderr log "Log line"
  stderr error "Foo bar"
  stderr warn "Foo bar"
  stderr note "Foo bar"
  stderr info "Foo bar"
  stderr debug "Foo bar"
  echo
  stderr ok "Foo bar"
  stderr pass "Foo bar"
  stderr fail "Foo bar"
  stderr failed "Foo bar"
  stderr skipped "Foo bar"
  echo
  for x in emerg crit error warn note debug \
        std_emerg std_crit std_error std_warn std_note std_info std_debug
    do
      $x "testing $x out"
    done
}

# experiment rewriting console output
clear_lines()
{
  local count=$1
  test -n "$count" || count=0

  while [ "$count" -gt -1 ]
  do
    # move forward to end, then erase one line
    echo -ne "\033[200C"
    echo -ne "\033[1K"
    # move up
    echo -ne "\033[1A"
    count=$(( $count - 1 ))
  done

  # somehow col is one off, ie. the next regular echo has the first character
  # eaten by the previous line. clean one line here
  echo
}

# read stdin. Once done use clear_lines to reset stdout
# could use this to post-process, reformat results of input.
# XXX using fold to determine the real amount of lines a given stream would have
# taken given terminal width ${cols}.
capture_and_clear()
{
  local tmpf=$(setup_tmpf)
  tee $tmpf
  mv $tmpf $tmpf.tmp
  fold -s -w $cols $tmpf.tmp > $tmpf
  lines=$(wc -l $tmpf | awk '{print $1}')
  clear_lines $lines
  echo Captured $lines lines >&2
}



# Main

#test -n "$lib_load" || {
#
#  case "$0" in "" ) ;; "-"* ) ;; * )
#    test -n "$scriptname" || scriptname="$(basename "$0" .sh)"
#    test -n "$verbosity" || verbosity=5
#    case "$1" in
#
#      load-ext ) ;; # External include, do nothing
#
#      load )
#          test -n "$scriptpath" || scriptpath="$(dirname "$0")"
#        ;;
#
#      error ) error "$2" $3 ;;
#      ok|warn|note|info|emerg|crit ) l=$1; shift ; stderr $l "$@" ;;
#      demo ) std_demo ;;
#
#      '' ) ;; # Ignore empty sh call
#
#      * ) # Setup SCRIPTPATH and include other scripts
#          echo "Ignored $scriptname argument(s) $0: $*" 1>&2
#        ;;
#
#    esac
#
#  ;; esac
#
#}

case "$0" in "" ) ;; "-"* ) ;; * )

  # Do nothing if loaded by lib-load
  test -n "$lib_load" || {

    # Otherwise set action with env __load
    test -n "$__load" || {

      # Sourced or executed without __load* env.

      # If executed, there may be arguments passed. Bourne shell does not
      # support argument passing to sourced scripts (Bash can and others
      # probably).

      # Here we do some 'detection'
      case "$1" in

        load|ext|load-ext )
            __load=ext
          ;;

        demo | \
        error | \
            ok|warn|note|info|emerg|crit )
            __load=boot
          ;;

      esac
    }
    case "$__load" in

      boot )
          test -n "$scriptpath" || scriptpath="$(dirname "$0")/script"
          test -n "$scriptname" || scriptname="$(basename "$0" .sh)"
          test -n "$verbosity" || verbosity=5
          eval base=$scriptname
        ;;

    esac
    case "$__load" in

      ext ) ;; # External include, do nothing

      boot )
          case "$1" in

            error ) shift ; error "$@" || exit $? ;;
            stderr ) shift ; stderr "$@" || exit $? ;;
            ok|warn|note|info|emerg|crit )
                stderr "$@" || exit $?
              ;;

          esac
        ;;

      * ) echo "Illegal std.lib load action '$__load/$*'" >&2 ; exit 1 ;;

esac ; } ;; esac

# See also: x-sh-tokens/0.0.1-dev script/std.lib.sh
# Id: script-mpe/
