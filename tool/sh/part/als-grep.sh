script_mpe_part_als_grep_load ()
{
  : source script-mpe:tool/sh/part/als-grep.sh
  . "${US_BIN:?}"/tool/sh/part/fun-grep.sh
}

grep_als ()
{
  : source script-mpe:tool/sh/part/als-grep.sh
}

# TODO: define user-grep as alias parts as well?
alias user-grep=''

alias stat-grep=grep-stat.sh
alias grep-stat=grep-stat.sh

#
