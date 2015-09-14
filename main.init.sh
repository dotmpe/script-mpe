#!/bin/sh

load()
{
    case "$(uname)" in Darwin )
            expr=bash-substr ;;
        Linux )
            expr=sh-substr ;;
    esac
}

