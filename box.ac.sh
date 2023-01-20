#!/usr/bin/env bash
# box.ac - auto-completion scripts for readline
# Created: 2015-09-05


__box_init () # ~ <Exec-Name>
{
  test -n "${1-}" || set -- box
  box=$(which $1) || {
    box=$(which $1.sh) || {
      $LOG warn : "Found no such exec" "$1" $? || return
    }
  }
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

__box_pref_ac_def () # ~ <Exec-Name> <Handle> # Add completions for box execname
{
  test -n "${2-}" || set -- "$1" "__box_bash_auto_complete"
  local box scriptname base
  __box_init "$1" || return
  eval "$(cat <<EOM
__box_ac_${base} ()
{
    local box cwd scriptname base ctags ; __box_init $1 || return
    $2
}
EOM
  )"
  complete -F __box_ac_${base} $1.sh $1
}


BOX_EXECS="box box.us*"\
" diskdoc docker-sh esop graphviz htd htd ino list match meta-sh"\
" redmine rst script-sh srv tasks topics twitter"\
" vagrant-sh vc x-test"

__uc_ac_init ()
{
  local box
  for box in "${@:?}"
  do
    case "$box" in
      ( *"*" ) __box_fun_ac_def ${box/\*} ;;
      ( * ) __box_pref_ac_def $box ;;
    esac
  done
}

# TODO: Fix descriptions
__uc_execnames_check ()
{
  #sh_fun ${lib_load:-uc_lib_load} || {
  #  PATH=$PATH:$PWD:$U_C/script
  #  uc_func () { sh_fun "$@"; }
  #  source "uc-lib.lib.sh" && uc_lib_init || return
  #}
  #$lib_load list htd ignores user-script &&
  #user_script_lib_init &&
  user_script_check
}


__us_cmds ()
{
  grep '^[[:alpha:]_][[:alnum:]_'"${US_EXTRA_CHAR:-}"']* *()' "${box:?}" |
      cut -d' ' -f1
}

__user_script_bash_autocomplete ()
{
  cur=${COMP_WORDS[COMP_CWORD]}
  COMPREPLY=( $(compgen -W "$(__us_cmds)" -- $cur) )
}


US_EXECS="box.ac.sh box.us.sh context.sh disk.uc.sh image outline.sh pl.sh "\
"projects.sh shellcheck-usage.sh sort.sh system-display "\
"system-status system-terminal tmux-session tmux-status user-desktop "\
"user-script.sh user-tools vlc-cli volume.sh zram-user"

__us_ac_init ()
{
  local us
  for us in "${@:?}"
  do
    __box_pref_ac_def "$us" __user_script_bash_autocomplete
  done
}

__us_execnames_check ()
{
  while read -r scrname scrsrc
  do
    execname=$(basename "$scrsrc")
    fnmatch "* $execname *" " $US_EXECS " || {
      $LOG warn : "Not in ac list $execname ($scrname user-script)"
    }
  done <<< "$(user_script_find)"
}


test -n "${user_script_loaded:-}" ||
  . "${US_BIN:="$HOME/bin"}"/user-script.sh

script_isrunning "box.ac" .sh && {
  base=box.ac
  script_baseext=.sh
  script_cmdals=
  script_defcmd=

} || {

  # Running interactively probably? Initialize auto completion.
  uc_lib_load str-uc std-uc &&
      __uc_ac_init $BOX_EXECS &&
      __us_ac_init $US_EXECS
}

# XXX This operates without defarg so command aliases and defcmd do not work
# so probably should overide help
#! script_isrunning "box.ac" || eval "set -- $(user_script_defarg "$@")"

script_entry "box.ac" "$@"

# Id: script-mpe/0.0.4-dev box-completion.sh                       ex:ft=bash:
