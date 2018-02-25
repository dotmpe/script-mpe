#!/bin/bash
       
set -e 
        
# Bash: https://www.cyberciti.biz/faq/linux-unix-howto-check-if-bash-variable-defined-not/
var_isset()
{
  [[ ! ${!1} && ${!1-unset} ]] && return 1 || return 0
}

var_isset "$@"
