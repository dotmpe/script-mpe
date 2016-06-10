#!/bin/bash


case "$(uname -s)" in



    Darwin )

        pstree "$@" > /tmp/pstree

        case "$@" in
            *-s" "* )
                str="$(echo "$@" | sed -E 's/^.*-s\ ([^\ ]+).*$/\1/')"
                word='s/'$str'/\\033[31m&\\033[0m/g'
                ;;
            *-p" "* )
                pid="$(echo "$@" | sed -E 's/^.*-p\ ([0-9]+).*$/\1/')"
                word='s/'$pid'/\\033[31m&\\033[0m/g'
                ;;
        esac

# tree: blue (34)
# pid: yellow (33)
# punctuation: grey
# -options: purple
# =values: green (32)

echo -e "$(cat /tmp/pstree | sed -E '
    s/^([\ [:punct:]]+)\ ([0-9]+)\ ([A-Za-z0-9_]+)/\\033[34m\1\ \\033[33m\2\ \\033[32m\3\ \\033[0m/g
    s/=([[:graph:]]+)/=\\033[0;32m\1\\033[0m/g
    s/\ -[^=\ ]+=?/\\033[0;35m&\\033[0m/g
    s/\.|\//\\033[1;30m&\\033[0m/g
    '$word'
')"

#    s/[{}]/\\033[31m&\\033[0m/g

        ;;


    Linux )

/usr/bin/pstree -U "$@" | sed '
    s/[-a-zA-Z]\+/\x1B[32m&\x1B[0m/g
    s/[{}]/\x1B[31m&\x1B[0m/g
    s/[─┬─├─└│]/\x1B[34m&\x1B[0m/g
'
        ;;

esac



