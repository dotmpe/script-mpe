#!/bin/sh


# stdio type detect - return char t(erminal) f(ile) p(ipe; or named-pipe, ie. FIFO)
# On Linux, uses /proc/PID/fd/NR: Usage: stdio_type NR PID
# On OSX/Darwin uses /dev/fd/NR: Usage: stdio_type NR
# IO: 0:stdin 1:stdout 2:stderr
#  
stdio_type()
{
  local io= pid=
  test -n "$1" && io=$1 || io=1
  test -n "$uname" || uname=$(uname)
  case "$uname" in

    Linux )
        test -n "$2" && pid=$2 || pid=$$

        test -e /proc/$pid/fd/${io} || error "No $uname FD $io"
        if readlink /proc/$pid/fd/$io | grep -q "^pipe:"; then
          export stdio_${io}_type=p
        elif file $( readlink /proc/$pid/fd/$io ) | grep -q 'character.special'; then
          export stdio_${io}_type=t
        else
          export stdio_${io}_type=f
        fi
      ;;

    Darwin )

        test -e /dev/fd/${io} || error "No $uname FD $io"
        if file /dev/fd/$io | grep -q 'named.pipe'; then
          export stdio_${io}_type=p
        elif file /dev/fd/$io | grep -q 'character.special'; then
          export stdio_${io}_type=t
        else
          export stdio_${io}_type=f
        fi
      ;;

  esac
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

  # see if it supports colors...
  echo="echo"
  case $TERM in

    *256color )
      LOG_TERM=256
      ncolors=$(tput colors)
      # FIXME echo -e something going on with BSD sh?
      echo="echo -e"
      ;;

    xterm* | ansi )
      LOG_TERM=16
      ncolors=$(tput -T xterm colors)
      ;;

    * )
      LOG_TERM=bw
      echo "Other term $TERM"
      ;;

  esac

  if test -n "$ncolors" && test $ncolors -ge 8; then

    test -z "$debug" || echo "ncolors=$ncolors"

    bld="$(tput bold)"
    underline="$(tput smul)"
    standout="$(tput smso)"
    norm="$(tput sgr0)"

    test -n "$verbosity" && {
      $verbosity -ge 7 && echo "${drgrey}colors: ${grey}$ncolors${norm}"
    }

    if test $ncolors -ge 256; then
      #blackb="\e[0;90m"
      #grey="\e[0;37m"
      prpl="\033[38;5;135m"
      blue="\033[38;5;27m"
      red="\033[38;5;196m"
      dylw="\033[38;5;214m"
      ylw="\033[38;5;220m"
      #norm="\033[0m"
      test "$CS" = 'dark' && {
        nrml="\033[38;5;254m"
        bnrml="\033[38;5;231m"
        grey="\033[38;5;244m"
        dgrey="\033[38;5;238m"
        drgrey="\033[38;5;232m"
      }
      test "$CS" = 'light' && {
        nrml="\033[38;5;240m"
        bnrml="\033[38;5;232m"
        grey="\033[38;5;245m"
        dgrey="\033[38;5;250m"
        drgrey="\033[38;5;255m"
      }

    else
      grey=${nrml}

      black="$(tput setaf 0)"
      red="$(tput setaf 1)"
      grn="$(tput setaf 2)"
      ylw="$(tput setaf 3)"
      blue="$(tput setaf 4)"
      prpl="$(tput setaf 5)" # magenta
      cyan="$(tput setaf 6)"
      nrml="$(tput setaf 7)"
      bnrml=${bld}${nrml}
    fi
  fi
#fi

log_bw()
{
  echo "$1"
}

log_16()
{
  printf "$1\n"
}

log_256()
{
  printf "$1\n"
}

# Normal log uses log_$TERM
# 1:fd 2:str 3:exit
log()
{
  test -n "$1" || return
  #test -n "$2" || return 1
  #test -n "$1" || set -- 1 "$@"
  test -n "$stdout_type" || stdout_type="$stdio_1_type"
  test -n "$stdout_type" || stdout_type=t

  case $stdout_type in t )
        key=$scriptname.sh
        test -n "$subcmd_name" && key=${key}${bb}:${bk}${subcmd_name}
        log_$LOG_TERM "${bb}[${bk}${key}${bb}] ${norm}$1"
        ;;

      p|f )
        key=$scriptname.sh
        test -n "$subcmd_name" && key=${key}${bb}:${bk}${subcmd_name}
        log_$LOG_TERM "${bb}# [${bk}${key}${bb}] ${norm}$1"
        ;;
  esac
}
err()
{
  # XXX seems ie grep strips colors anyway?
  [ -n "$stdout_type" ] || stdout_type=$stdio_2_type
  case "$(echo $1 | tr 'A-Z' 'a-z')" in

    crit*)
        bb=${ylw}; bk=$nrml
        test "$CS" = "light" \
          && crit_label_c="\033[38;5;226;48;5;249m" \
          || crit_label_c="\033[48;5;0m${ylw}"

        log "${bld}${crit_label_c}$1${norm}${blackb}: ${bnrml}$2${norm}" 1>&2 ;;
    err*)
        bb=${red}; bk=$grey
        log "${bld}${red}$1${blackb}: ${norm}${bnrml}$2${norm}" 1>&2 ;;
    warn*)
        bb=${dylw}; bk=$grey
        test "$CS" = "light" \
            && warning_label_c="\033[38;5;255;48;5;220m"\
            || warning_label_c="\033[38;5;214;48;5;255m";
        log "${bld}${warning_label_c}$1${norm}${grey}${bld}: ${nrml}$2${norm}" 1>&2 ;; notice )
        bb=${prpl}; bk=$grey
        log "${grey}${nrml}$2${norm}" 1>&2 ;;
    info )
        bb=${blue}; bk=$grey
        log "${nrml}$2${norm}" 1>&2 ;;

    ok )
        bb=${grn}; bk=$grey
        log "${nrml}$2${norm}" 1>&2 ;;
    * )
        bb=${drgrey} ; bk=$dgrey
        log "${grey}$2" 1>&2 ;;

  esac
  [ -z "$3" ] || exit $3
}

test_v()
{
  test -z "$verbosity" && return || {
    test $verbosity -ge $1 && return || return 1
  }
}

test_exit()
{
  test "$1" != "0" -a -z "$1" && return 1 || exit $1
}

#emerg() 1
#crit() 2
crit()
{
  test_v 3 || test_exit $2 || return 0
  err "Crit" "$1" $2
}
error()
{
  test_v 3 || test_exit $2 || return 0
  err "Error" "$1" $2
}
warn()
{
  test_v 4 || test_exit $2 || return 0
  err "Warning" "$1" $2
}
note()
{
  test_v 5 || test_exit $2 || return 0
  err "Notice" "$1" $2
}
info()
{
  test_v 6 || test_exit $2 || return 0
  err "Info" "$1" $2
}
debug()
{
  test_v 7 || test_exit $2 || return 0
  err "Debug" "$1" $2
}

std_demo()
{
  scriptname=std cmd=demo
  log "Log line"
  error "Foo bar"
  warn "Foo bar"
  note "Foo bar"
  info "Foo bar"
  debug "Foo bar"

  for x in error warn note info debug
    do
      $x "testing $x out"
    done
}

# experiment rewriting console output
clear_lines()
{
  count=$1
  [ -n "$count" ] || count=0

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

# read std. Once done use clear_lines to reset stdout
# could use this to post-process, reformat results of input.
# XXX using fold to determine the real amount of lines a given stream would have
# taken given terminal width ${cols}.
capture_and_clear()
{
  tee /tmp/htd-out
  mv /tmp/htd-out /tmp/htd-out.tmp
  fold -s -w $cols /tmp/htd-out.tmp > /tmp/htd-out
  lines=$(wc -l /tmp/htd-out|awk '{print $1}')
  clear_lines $lines
  echo Captured $lines lines
}

