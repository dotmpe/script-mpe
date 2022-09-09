#!/bin/sh

## @Dev


htd_rule_post_proc()
{
  true
}

#htd_process()
#{
grep '.*uid:\([0-9a-zA-Z_-][0-9a-zA-Z_-]*\)\($\|\ \).*' |
  sed -E 's/^(.*[[:space:]])?uid:([0-9a-zA-Z_-]*).*$/\2/'
#}

