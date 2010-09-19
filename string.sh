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
