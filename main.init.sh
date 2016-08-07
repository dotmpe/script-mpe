#!/bin/sh

#load()
#{
    case "$(uname)" in 
        Darwin )
            expr=bash-substr ;;
        Linux )
            expr=sh-substr ;;
        * )
            error "Unable to init expr" 1;;
    esac
#}

