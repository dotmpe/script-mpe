#!/bin/bash

string_load ()
{
  set -e
  . ~/bin/str-htd.lib.sh
  test -z "${DEBUG:-}" || set -x
}

# Bash stringtools
function rpad {
    if [ "$1" ]; then
        word="$1";
    else
        word="";
    fi;

    if [ "$2" ]; then
        len=$((`echo $2 | sed 's/[^0-9]//g'`));
    else
        len=${#word};
    fi;

    if [ "$3" ]; then
        padding="$3";
    else
        padding=" ";
    fi;

    while [ ${#word} -lt $len ]; do
        word="$word$padding";
    done;
    while [ ${#word} -gt $len ]; do
        word=${word:0:$((${#word}-1))}
    done;
    echo "$word";
}
function lpad {
    if [ "$1" ]; then
        word="$1";
    else
        word="";
    fi;

    if [ "$2" ]; then
        len=$((`echo $2 | sed 's/[^0-9]//g'`));
    else
        len=${#word};
    fi;

    if [ "$3" ]; then
        padding="$3";
    else
        padding=" ";
    fi;

    while [ ${#word} -lt $len ]; do
        word="$padding$word";
    done;
    while [ ${#word} -gt $len ]; do
        word=${word:1:$((${#word}-1))}
    done;
    echo "$word"
}
function cpad {
    if [ "$1" ]; then
        word="$1";
    else
        word="";
    fi;

    if [ "$2" ]; then
        len=$((`echo $2 | sed 's/[^0-9]//g'`));
    else
        len=${#word};
    fi;

    if [ "$3" ]; then
        padding="$3";
    else
        padding=" ";
    fi;

    while [ ${#word} -lt $len ]; do
        word="$word$padding";
        if [ ${#word} -lt $len ]; then
            word="$padding$word"
        fi;
    done;
    while [ ${#word} -gt $len ]; do
        word=${word:0:$((${#word}-1))}
        if [ ${#word} -gt $len ]; then
            word=${word:1:$((${#word}-1))}
        fi;
    done;

    echo "$word";
}



if [ "$(basename -- "$0")" == "string" ]
then
  string_load

  case "${1-}" in

    str-padd-left ) str_sh_padd_ch "$2" "$3" "$4" ;;
    str-padd-right ) str_sh_padd_ch "$2" "" "$4" "$3" ;;

    * | "" ) exit 64 ;;

  esac

elif [ "$(basename -- "$0")" == "string.sh" ]
then
  string_load
  "$@"
fi
