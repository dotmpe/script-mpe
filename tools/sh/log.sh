#!/bin/sh

# Logger - arg-to-colored ansi line output
# Usage:
#   log.sh [Line-Type] [Header] [Msg] [Ctx] [Exit]


test -n "$verbosity" || {
  case "${v-}" in [0-9] ) verbosity="$v";; esac
}
test -n "$verbosity" || {
  test -n "$DEBUG" && verbosity=7 || verbosity=6
}


# Return level number as string for use with line-type or logger level, channel
log_level_name() # Level-Num
{
  case "$1" in
      0 ) echo emerg ;;
      1 ) echo alert ;;
      2 ) echo crit ;;
      3 ) echo error ;;
      4 ) echo warn ;;
      5 ) echo note ;;
      6 ) echo info ;;
      7 ) echo debug ;;

      5.1 ) echo ok ;;
      4.2 ) echo fail ;;
      3.3 ) echo err ;;
      6.4 ) echo skip ;;
      2.5 ) echo bail ;;
      7.6 ) echo diag ;;

      * ) return 1 ;;
  esac
}

log_level_num() # Level-Name
{
  case "$1" in
      emerg ) echo 0 ;;
      crit | FIXME ) echo 1 ;;
      alert | bail | TODO ) echo 2 ;;
      error | err ) echo 3 ;;
      warn  | fail ) echo 4 ;;
      note  | notice | ok ) echo 5 ;;
      info  | skip | TODO ) echo 6 ;;
      debug | diag ) echo 7 ;;

      * ) return 1 ;;
  esac
}

# set log-key to best guess
log_src_id_key_var()
{
  test -n "${log_key-}" || {
    test -n "${stderr_log_channel-}" && {
      log_key="$stderr_log_channel"
    } || {
      test -n "${base-}" -a -z "$scriptname" || {
        log_key="\$CTX_PID:\$scriptname/\$scriptpid"
      }
      test -n "$log_key" || {
        test -n "${scriptext-}" || scriptext=.sh
        log_key="\$base\$scriptext"
      }
      test -n "$log_key" || echo "Cannot get log-src-id key" 1>&2;
    }
  }
}

log_src_id()
{
  eval echo \"$log_key\"
}

# left align first columnt at:
test -n "$FIRSTTAB" || {
  # Set initial vl to 20% of screen width
  FIRSTTAB=$(echo "$(tput cols) * 20 / 100" | bc)
  FIRSTDBGTAB=$(echo "$(tput cols) * 40 / 100" | bc)
}

if [ -z "$CS" ]
then
  # XXX: echo "$(log_src_id): warning, using dark colorscheme (set CS to override)" 1>&2
  CS=dark
fi

COLOURIZE=yes

# Shell colors
if [ "$COLOURIZE" = "yes" ]
then

  bold="$(tput bold)"
  underline="$(tput smul)"
  standout="$(tput smso)"

  normal="$(tput sgr0)"

  c0="$(tput setaf 0)" # primary fg
  c00="$(tput setab 0)" # primary bg

  # teal
  c6="$(tput setaf 6)" # primary fg
  c60="$(tput setab 6)" # primary bg

  c8="$(tput setaf 8)" # primary fg
  c80="$(tput setab 8)" # primary bg

  #c7="$(tput setaf 7)" # primary fg
  c70="$(tput setab 7)" # primary bg

  if [ "$CS" = "light" ]
  then
    # primary fg, black

    # pale (inverted white)
    c7="$standout$(tput setaf 7)"
    # hard (bright black, ie. dark gray)
    c9="$bold$0"
  else
    # primary, pale white
    # pale (normal white, ie. light gray)
    c7="$(tput setaf 7)"
    # hard (bold white)
    c9="$bold$7"
  fi
  # warning color, red
  c1="$bold$(tput setaf 1)"
  # ok color, green
  c2="$(tput setaf 2)"
  c21="$bold$c2"
  # running, orange
  c3="$(tput setaf 3)"
  c31="$bold$c3"
  # updated, blue
  c4="$(tput setaf 4)"
  c41="$bold$c4"
  # generic, purple
  c5="$(tput setaf 5)"
  c51="$bold$c5"
fi
## Make output strings
mk_title_blue="$c7$c41%s$c7:$c0"
mk_title_blue_faint="$c7$c4%s$c7:$c0"
mk_p_trgt_blue="$c41[$c7%s$c41]$c0"
#mk_p_trgt_blue_faint="$c4[$c7%s$c4]$c0"
mk_trgt_blue="$c41<$c7%s$c41>$c0"
#mk_trgt_blue_faint="$c4<$c7%s$c4>$c0"
mk_trgt_yellow="$c31<$c7%s$c31>$c0"
#mk_trgt_yellow_faint="$c3<$c7%s$c3>$c0"
mk_p_trgt_yellow="$c31[$c7%s$c31]$c0"
mk_p_trgt_yellow_faint="$c3[$c7%s$c3]$c0"
mk_p_trgt_green="$c21[$c7%s$c21]$c0"
mk_trgt_green="$c21<$c7%s$c21>$c0"
#mk_trgt_green_faint="$c2<$c7%s$c2>$c0"
mk_trgt_red="$c1<$c7%s$c1>$c0"
mk_p_trgt_red="$c1[$c7%s$c1]$c0"
mk_updtd="$c4<$c7%s$c4>$c0"

mk_trgt_purple="$c5<$c7%s$c5>$c0"
mk_p_trgt_purple="$c5[$c7%s$c5]$c51"

__log() # [Line-Type] [Header] [Msg] [Ctx] [Exit]
{
  test -n "${2-}" || {
    test -n "${log_key:-}" || log_src_id_key_var
    test -n "$2" || set -- "$1" "$(log_src_id)" "$3" "$4" "$5"
    test -n "$2" || set -- "$1" "$0" "$3" "$4" "$5"
  }

    # XXX: should use src-id
  # test -n "$2" || {
  #   set -- "$1" "$scriptname" "$3" "$4" "$5"
  #   # XXX: prolly want shell-lib-load base macro instead
  #   test -n "$2" || set -- "$1" "$base" "$3" "$4" "$5"
  #   test -n "$2" || set -- "$1" "$0" "$3" "$4" "$5"
  # }

  lvl=$(log_level_num "$1")
  test -z "$lvl" -o -z "$verbosity" || {
    test $verbosity -ge $lvl || {
      test -n "$5" && exit $5 || {
        return 0
      }
    }
  }

  linetype=$(echo $1 | tr '[:upper:]' '[:lower:]')
  targets=$(echo "$2")
  trgt_len=${#targets}
  msg=$3
  sources=$(echo "$4")

  if [ -n "$sources" ];
  then
    sources=$(printf "$mk_trgt_blue" "$sources")
    msg="$msg $sources"
  fi
  case "$linetype" in
    header | header1) # blue
      #targets=$(printf "$mk_title_blue" "$targets")
      targets=$(printf "$mk_p_trgt_blue" "$targets")
      ;;
    header2 )
      targets=$(printf "$mk_title_blue" "$targets")
      ;;
    header3 )
      targets=$(printf "$mk_title_blue_faint" "$targets")
      ;;
    debug )
     targets="$(printf "%s[%s%s%s]%s" "$c0" "$c8" "$targets" "$c0" "$normal")";
        FIRSTTAB=$FIRSTDBGTAB
        #trgt_len=5
        #$(printf "$mk_p_trgt_yellow_faint" "$targets")
      ;;
    verbose | warn*  )
      targets=$(printf "$mk_p_trgt_yellow_faint" "$targets")
      ;;
    attention | crit* )
      targets=$(printf "$mk_p_trgt_yellow" "$targets")
      ;;
    file[_-]target )
      targets=$(printf "$mk_trgt_yellow" "$targets")
      ;;
    file[_-]ok )
      targets=$(printf "$mk_trgt_green" "$targets")
      ;;
    file[_-]warn* )
      targets=$(printf "$mk_trgt_yellow" "$targets")
      ;;
    file[_-]err* ) # red
      targets=$(printf "$mk_trgt_red" "$targets")
      ;;
    err* | fatal | fail* ) # red
      targets=$(printf "$mk_p_trgt_red" "$targets")
      ;;
    ok | "done" | info | pass )
      targets=$(printf "$mk_p_trgt_green" "$targets")
      ;;

    * )
      targets=$(printf "$mk_p_trgt_purple" "$targets")
      ;;

  esac
  case "$linetype" in
    file[_-]error|file[_-]warn*|file[_-]target|file[_-]ok|header|header1|header2|header3|debug|info|attention|error|verbose)
      ;;
    fatal|ok|'done'|* )
      if [ -n "$msg" ]
      then msg="$c9$1$c0, $msg";
      else msg="$c9$1$c0"; fi
      ;;
  esac
  if [ -n "$msg" -a -z "$sources" ]
  then
    msg="$msg.";
  fi
  len=$(expr $FIRSTTAB - $trgt_len)
  case "$linetype" in
    debug)
      len=$(expr $len + 2)
      ;;
    'header2'|header3)
      len=$(expr $len + 1)
      ;;

  esac

  if [ $len -lt 0 ]; then len=0; fi
  # FIXME: should use printf
  padd=" ";
  padding=''
  while [ ${#padding} -lt $len ]; do
    padding="$padd$padding"
  done;
  printf " %s%s %s%s\n" "$padding" "$targets" "$msg" "$c0$normal" >&2

  unset lvl linetype targets trgt_len msg souces padd padding
  test -z "$5" || exit $5
}


# Start in stream mode or print one line and exit.
if test "$1" = '-'
then
  export IFS="	"; # tab-separated fields for $inp
  while read lt p m c s;
  do
    __log "$lt" "$p" "$m" "$c" "$s";
  done
else
  case "$1" in
    demo )
        set -- demo "Test message line" "123"
        __log "error" "$@"
        __log "warn" "$@"
        __log "note" "$@"
        __log "info" "$@"
        __log "debug" "$@"
        __log "ok" "$@"
        __log "fail" "$@"
      ;;
    * )
        __log "$1" "$2" "$3" "$4" "$5"
      ;;
  esac
fi
# Sync: U-S:
