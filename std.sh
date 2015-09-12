#!/bin/sh


# Linux stdio type detect
stdio_type()
{
  test -n "$1" && io=$1 || io=1
  test -n "$2" && pid=$2 || pid=$$
  if readlink /proc/$pid/fd/$io | grep -q "^pipe:"; then
    export stdio_${io}_type=p
  elif file $( readlink /proc/$pid/fd/$io ) | grep -q "character special"; then
    export stdio_${io}_type=t
  else
    export stdio_${io}_type=f
  fi
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
if [ -t 1 ]; then

  # see if it supports colors...
  echo="echo"
  case $TERM in

    xterm-256color )
      LOG_TERM=256
      ncolors=$(tput colors)
      # FIXME echo -e something going on with BSD sh?
      echo="echo -e"
      ;;

    xterm* )
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

    #black="\e[0;30m"
    black=

    bld="$(tput bold)"
    underline="$(tput smul)"
    standout="$(tput smso)"
    norm="$(tput sgr0)"
    black="$(tput setaf 0)"
    red="$(tput setaf 1)"
    grn="$(tput setaf 2)"
    ylw="$(tput setaf 3)"
    blue="$(tput setaf 4)"
    prpl="$(tput setaf 5)" # magenta
    cyan="$(tput setaf 6)"
    white="$(tput setaf 7)"
    bwhite=${bld}${white}

    if test $ncolors -ge 256; then
      #blackb="\e[0;90m"
      #grey="\e[0;37m"
      grey=
    else
      grey=${white}
    fi
  fi
fi

log_bw()
{
  echo "$1"
}

log_16()
{
  echo "$1"
}

log_256()
{
  echo "$1"
}

# Normal log uses log_$TERM
# 1:fd 2:str 3:exit
log()
{
  test -n "$1" || return
  #test -n "$2" || return 1
  #test -n "$1" || set -- 1 "$@"
  test -n "$stdout_type" || stdout_type=$(eval echo \$stdio_${1}_type)
  test -n "$stdout_type" || stdout_type=t

  case $stdout_type in t )

        key=${grey}$scriptname.sh
        test -n "$subcmd_name" && key=${key}${bb}:${grey}${subcmd_name}

        log_$LOG_TERM "${pref}${bb}[${key}${bb}] ${norm}$1"
        ;;

      p|f )
        key=${grey}$scriptname.sh
        test -n "$subcmd_name" && key=${key}:${subcmd_name}
        log_$LOG_TERM "# [${key}] $1"
        ;;
  esac
}
err()
{
  # XXX seems ie grep strips colors anyway?
  [ -n "$stdout_type" ] || stdout_type=$stdio_2_type
  case "$(echo $1 | tr 'A-Z' 'a-z')" in
    err*)
        bb=${red}
        log "${bld}${red}$1${blackb}: ${bwhite}$2${norm}" 1>&2 ;;
    warn*)
        bb=${ylw}
        log "${ylw}$1${grey}: ${grey}$2${norm}" 1>&2 ;;
    notice )
        bb=${prpl}
        log "${prpl}$1${grey}: ${grey}$2${norm}" 1>&2 ;;
    info )
        bb=${blue}
        log "${grey}$2${norm}" 1>&2 ;;
    ok )
        bb=${grn}
        log "${grey}$2${norm}" 1>&2 ;;
    * )
        bb=${blackb}
        log "${norm}$2" 1>&2 ;;
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

