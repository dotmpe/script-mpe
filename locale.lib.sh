#!/bin/sh

locale_lib_load ()
{
  true
}

locale_list () #
{
  locale -a
}

# Check if <lang>_<country>.<encoding> exists.
locale_tag_exists ()
{
  test $# -eq 1 -a -n "${1-}" || return 98
  match_grep "$1"
  locale_list | grep -q "^$p_$"
}

# Check if <lang> exists
locale_lang_exists ()
{
  test $# -eq 1 -a -n "${1-}" || return 98
  locale_list | grep -q "^${1}_[A-Z]*\(\..*\)\?$"
}

# Check if <country> exists
locale_country_exists ()
{
  test $# -eq 1 -a -n "${1-}" || return 98
  locale_list | grep -q "^[A-Z]*_${1}\(\..*\)\?$"
}

#
