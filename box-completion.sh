#!/usr/bin/env bash
# box-comp - auto-completion scripts for readline
# Created: 2015-09-05

__box_init () # ~ <Exec-Name>
{
  test -n "${1-}" || set -- box
  box=$(which $1)
  cwd="$(dirname "$box")"
  scriptname="$(basename "$box" .sh)"
  base="$(echo "$scriptname" | tr '-' '_')"

  #case "$cwd" in
  #  $HOME/.conf/script ) ctags=$HOME/.conf/tags ;;
  #  * ) ctags=$cwd/tags ;; esac

  # eval "$(grep $base'_spc__' $box)"
}

__box_cmds()
{
  grep -oP '^'$base'__\K\w+' "$box" | sort -u | tr '_' '-'
}

__box_options()
{
  grep -oP '^'$base'_spc__[\w_]+=.\K.+(?=["'"'"'])' "$box" |
      sort -u | cut -f1 -d' ' |
      tr '_' '-' | tr '|' '\n'
}

__box_aliases()
{
  grep -oP '^'$base'_als__\K\w+(?==)' "$box" | sort -u | tr '_' '-'
}

# Generate AC for script. See __box_init for settings.
__box_bash_auto_complete ()
{
  test -n "${box-}" || __box_init "$@"

  local cur_idx cur prev
  cur=${COMP_WORDS[COMP_CWORD]}
  local prev=${COMP_WORDS[COMP_CWORD-1]}

  # First word is sub-command
  test $COMP_CWORD -eq 1 || return

  COMPREPLY=( $(compgen -W "$(__box_cmds) $(__box_aliases) $(__box_options)" -- $cur) )
}

__box_ac_def () # ~ <Exec-Name> <Handle> # Add completions for box execname
{
  test -n "${2-}" || set -- "$1" "__box_bash_auto_complete"
  local box scriptname base
  box="$(which "$1.sh")"
  scriptname="$(basename "$box" .sh)"
  base="$(echo "$scriptname" | tr '-' '_')"
  eval "$(cat <<EOM
__box_ac_${base} ()
{
    local box cwd scriptname base ctags ; __box_init $1.sh || return
    $2
}
EOM
  )"
  complete -F __box_ac_${base} $1.sh $1
}


BOX_EXECS="box diskdoc docker-sh esop graphviz htd htd ino list match meta-sh"\
" redmine rst script-sh srv tasks topics twitter vagrant-sh vc x-test"

__uc_ac_init ()
{
  local box
  for box in "$@"
  do
    __box_ac_def $box
  done
}

__uc_execnames_check ()
{
  uc_lib_load user-scripts &&
  user_scripts_lib_init &&
  user_scripts_check
}

uc_lib_load str-uc std-uc && __uc_ac_init $BOX_EXECS

# Id: script-mpe/0.0.4-dev box-completion.sh                       ex:ft=bash:
