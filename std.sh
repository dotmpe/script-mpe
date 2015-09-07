#!/bin/sh

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
  ncolors=$(tput colors)

  echo="echo"
  case $TERM in 
    xterm-256color )
      # FIXME echo -e something going on with BSD sh?
      echo="echo -e"
      ;;
    xterm* )
      ncolors=$(tput -T xterm colors)
      ;;
  esac

  if test -n "$ncolors" && test $ncolors -ge 8; then

    test -z "$debug" || echo "ncolors=$ncolors"

    black="\e[0;30m"

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
      blackb="\e[0;90m"
      grey="\e[0;37m"
    else
      grey=${white}
    fi
  fi
fi


# stdio/stderr/exit util
log()
{
  [ -n "$(echo "$*")" ] || return 1;
  key=${grey}$scriptname.sh
  test -n "$subcmd_name" && key=${key}${bb}:${grey}${subcmd_name}
  echo "${pref}${bb}[${key}${bb}] ${norm}$1"
}
err()
{
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
  [ -z $3 ] || exit $3
}

error()
{
  err "Error" "$1" "$2"
}
warn()
{
  err "Warning" "$1" "$2"
}
note()
{
  err "Notice" "$1" "$2"
}
info()
{
  err "Info" "$1" "$2"
}
debug()
{
  err "Debug" "$1" "$2"
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

# x-platform regex match since Bash/BSD test wont chooche on older osx
x_re()
{
  echo $1 | grep -E "^$2$" > /dev/null && return || return 1
}


