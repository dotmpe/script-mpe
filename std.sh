#!/bin/sh


# check if stdout is a terminal...
if [ -t 1 ]; then

  # see if it supports colors...
  ncolors=$(tput colors)
  echo="echo"
  case $TERM in 
    xterm-256color )
      # FIXME echo -e
      echo="echo -e"
      ;;
    xterm* )
      ncolors=$(tput -T xterm colors)
      ;;
  esac

  if test -n "$ncolors" && test $ncolors -ge 8; then

    test -z "$debug" || echo "ncolors=$ncolors"

    if test $ncolors -ge 256; then
      grey="\e[0;37m"
      black="\e[0;30m"
      blackb="\e[0;90m"
    fi

    bold="$(tput bold)"
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
  fi
fi


# stdio/stderr/exit util
log()
{
  [ -n "$(echo "$*")" ] || return 1;
  ${echo} "${blackb}[${grey}$scriptname.sh${blackb}] $1"
}
err()
{
  case "$(echo $1 | tr 'A-Z' 'a-z')" in
    err*) log "${bold}${red}$1${blackb}: ${whte}$2${norm}" 1>&2 ;;
    warn*) log "${ylw}$1${grey}: ${grey}$2${norm}" 1>&2 ;;
    notice ) log "${prpl}$1${grey}: ${grey}$2${norm}" 1>&2 ;;
    * ) log "${norm}$2" 1>&2 ;;
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
  err " " "$1" "$2"
}

std_demo()
{
  scriptname=std cmd=demo
  log "Log line"
  error "Foo bar"
  warn "Foo bar"
  note "Foo bar"
  info "Foo bar"
}

