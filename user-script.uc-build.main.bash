# Copyright: (C) 2026 hari <hari@t470p>
#
# Distributed under terms of the MIT license.

#%'main'
: "${BASH_SOURCE[0]##*/}"
if [[ ${0##*/} == "${_%%.*}" || "${0##*/}" == "${_%%.*}".* ]]
then
  #shellcheck disable=1009,1054,1056,1072,1073,1083
  {{main.content}}
fi
#/main

# Id: user-script         vim:set ft=bash sw=2 sts=2 et:
