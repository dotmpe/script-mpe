#!/bin/bash
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
if [ ${0:${#0}-9} == "string.sh" ]
then
    $1 ${@:2}
#else 
# XXX: function scope is local, but still overriden by any like-named symlinks
#    string_sh=$(readlink $0)
#    echo $0 $string_sh
#    $string_sh $0 ${@:1}
fi
