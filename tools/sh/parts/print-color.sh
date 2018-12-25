#!/bin/sh

c_normal="$(tput sgr0)"
c_black="$(tput setaf 0)"
c_red="$(tput setaf 1)"
c_green="$(tput setaf 2)"
c_yellow="$(tput setaf 3)"
#c_blue="$(tput setaf 4)"
#c_purple="$(tput setaf 5)" # magenta
c_bold="$(tput bold)"
c_default="$(tput setaf 7)"

print_red()
{
  test $# -eq 2 || return
  test -n "$1" || set -- "$scriptname" "$2"
  printf "%s[%s%s%s] %s%s%s\n" "$c_red" "$c_default" "$1" "$c_red" "$c_default" "$2" "$c_normal"
}

print_yellow()
{
  test $# -eq 2 || return
  test -n "$1" || set -- "$scriptname" "$2"
  printf "%s[%s%s%s] %s%s%s\n" "$c_yellow" "$c_default" "$1" "$c_yellow" "$c_default" "$2" "$c_normal"
}

print_green()
{
  test $# -eq 2 || return
  test -n "$1" || set -- "$scriptname" "$2"
  printf "%s[%s%s%s] %s%s%s\n" "$c_green" "$c_default" "$1" "$c_green" "$c_default" "$2" "$c_normal"
}
