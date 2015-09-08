#!/bin/sh

incr_c()
{
  incr c $1
}

incr()
{
  local incr_amount
  test -n "$2" && incr_amount=$2 || incr_amount=1
  v=$(eval echo \$$1)
  export $1=$(( $v + $incr_amount ))
}

# Get help str if exists for $section $id
# 1:section-number 2:help-id
# :*:help_descr
try_help()
{
  help_descr=$(eval echo "\$man_$(echo $1)$(echo $2)")
  test -n "$help_descr" && echo "$help_descr" || return 1
}

# Run through all help sections for given string, echo and return on first
# 1:str
# :
echo_help()
{
  mkid _$1
  #try_exec_func ${help_base}__usage $1 || std_usage $1
  # 1: commands
  # 5: config files
  # 7: overview, conventions, misc.
  try_help 1 $id && return 0 || \
  try_help 5 $id && return 0 || \
  try_help 7 $id && return 0
  return 1
}

std_help()
{
  local help_base=$1
  shift 1

  test -z "$1" && {

    try_exec_func ${help_base}__usage $1 || std_usage $1
    # FIXME _commands and _docs std sub-commands
    try_exec_func ${help_base}_commands || noop
    try_exec_func ${help_base}_docs || noop

  } || {

    echo_help $1 || error "no help '$1'"
  }
}

std_usage()
{
  test -z "$1" && {
    echo "$scriptname.sh Bash/Shell script helper"
    echo 'Usage:'
    echo "  $scriptname <cmd> [<args>..]"
  } || {
    echo -n "$scriptname $1: "
  }
}

# Find shell script location with or without extension
# 1:basename:scriptname
# :fn
locate_name()
{
  local name=
  [ -n "$1" ] && name=$1 || name=$scriptname
  [ -n "$name" ] || error "script name required" 1
  fn=$(which $name)
  [ -n "$fn" ] || fn=$(which $name.sh)
  [ -n "$fn" ] || return 1
}

get_subcmd_valid_flags()
{
  local flag=$1
  shift 1
  test -z "$*" && {
    test -z "$subcmd_name" || {
      error "'$subcmd_name' does not accept -$flag" 1
    }
  }
  fnmatch "*$subcmd_name*" "$*" || {
    error "'$subcmd_name' does not accept -$flag" 1
  }
  case $subcmd_name in
      init ) case $flag in c ) return;; esac ;;
      create ) case $flag in i ) return;; esac ;;
  esac
  return 1
}

parse_subcmd_alias()
{
  c=0
  get_cmd_alias subcmd $1
  test -n "$subcmd_alias" && {
    c=1
    subcmd_name=$subcmd_alias
  } || return 1
}

parse_subcmd_opts()
{
  local o=
  while getopts faglicvqsn o
  do
    case "$o" in

    #r ) subcmd=run;;
    #n ) subcmd=new;;
    i ) get_subcmd_valid_flags $o init create; subcmd=init;;
    c ) get_subcmd_valid_flags $o init create; subcmd=create;;
    #d ) subcmd=deinit;;

    f ) get_subcmd_valid_flags $o new; choice_force=true;;
    a ) get_subcmd_valid_flags $o list; choice_all=true;;
    g ) get_subcmd_valid_flags $o run init; choice_global=true;;
    l ) get_subcmd_valid_flags $o; choice_local=true;;

    n ) dry_run=true ;;
    s ) silence=true; verbosity=0;;
    #S ) silence=$OPTARG;;
    v ) test $silent || verbosity=$(( $verbosity + 1 ));;
    q ) test $verbosity -ne 0 || silence=7; verbosity=0;;

    [?] )
      echo "Error $o"
      print >&2 "Usage: $0 [-s] [-d seplist] file ..."
      return 2
      ;;

    esac
  done
  c=$(( $OPTIND -1 ))
}

get_subcmd_args()
{
  local sc=0 tc=$c

  while [ $# -gt 0 ]
  do  case "$1" in

    -- )
      break
      ;;

    -* )
      parse_subcmd_alias $* && {
          test $c -gt 0 && {
            sc=$(( $c + $sc )); shift $c ; c=0;
            continue
          }
      } || noop
      parse_subcmd_opts $* && {
        test $c -gt 0 && {
          sc=$(( $c + $sc )); shift $c ; c=0;
          continue
        }
      } || { r=$?
        test $r -eq 1 && continue
        error "unparsable opt? $1 from '$*' returns '$r'"
      }
      ;;

    * )
      test -z "$subcmd_name" && {

        subcmd_name=$1

      } || {

        try_exec_func ${script_name}__init_args $* && {

          test $c -gt 0 && {
            sc=$(( $c + $sc )); shift $c ; c=0;
            continue
          }

        } || {

          # XXX 
          note "subcmd should parse $*"
          break
        }
      }
      ;;

    esac

    incr sc
    shift

  done

  c=$tc
  test $sc -gt 0 && {
    c=$(( $c + $sc ))
  }

  # XXX swap script-name with script-subcmd-name arg if latter is empty.. # always?
  if test -n "$script_name" -a -z "$script_subcmd_name"
  then
    script_subcmd_name=$script_name
    script_name=
  fi
}

get_cmd_func_name()
{
    # XXX 'local' seems better than 'eval'
    # set don't work that good or using it wrong. No declare, typeset.
    #echo ${func_pref} $(eval echo \${${1}_name}) ${func_suf}
    #echo ${1}_func=$(eval echo "${func_pref}\${${1}_name}${func_suf}" | tr '-' '_')
    # FIXME: test this.
    export ${1}_func=$(eval echo "${func_pref}\${${1}_name}${func_suf}" | tr '-' '_')
}

get_cmd_alias()
{
    export ${1}_alias=$(eval echo \$als_$(echo $2 | tr '-' '_'))
}

get_cmd_func()
{
    local func_pref= func_suf= tag=

    # get extra function name parts
    for tag in pref suf; do
      # allow empty setting
      var_isset ${1}_func_${tag} && {
        export func_${tag}=$(eval echo \$${1}_func_${tag})
        debug "set func_${tag} for ${1} to $(eval echo \$func_${tag})"
      }
    done
    var_isset func_pref || local func_pref=c_

    # get cmd_name
    test -n "$(eval echo \$${1}_name)" || local ${1}_name=$(eval echo \$${1}_def)

    get_cmd_func_name $1
    unset func_pref func_suf tag
}

main_load()
{
  local r=
  try_exec_func load || {
    r=$?; test -n "$1" || error "std load failed" $r
  }
  test -n "$1" || return
  try_exec_func ${1}__load || error "${1} load failed" $?
}

main_debug()
{
  debug "vars: 
    args=$*
    cmd=$base
    subcmd_name=$subcmd_name
    script_name=$script_name
    script_subcmd=$script_subcmd

    silent=$silent
    silence=$silence
    verbosity=$verbosity

    subcmd_alias=$subcmd_alias
    subcmd_func=$subcmd_func
    subcmd_func_pref=$subcmd_func_pref
    subcmd_func_suf=$subcmd_func_suf
    subcmd_name=$subcmd_name
  "
}


#  local scriptname= base=

#  local subcmd_def=
#  local subcmd_pref= subcmd_suf=
#  local subcmd_func_pref= subcmd_func_suf=

main()
{
  local subcmd_name= subcmd_alias= subcmd_func= e= c=0 dry_run=

  local silence= choice_force= choice_all= choice_local= choice_global=

  get_subcmd_args $*
  test $c -gt 0 && shift $c ; c=0
  get_cmd_func subcmd
  main_debug $*

  main_load $base
  debug "$base loaded"

  func_exists $subcmd_func || {
    debug "no such subcmd-func $subcmd_func"
    try_exec_func ${base}__usage || std_usage
    test -z "$subcmd_name" && {
      error 'No command given' 1
    } || {
      error "No such command: $subcmd_name" 2
    }
  }

  test -z "$dry_run" \
    && debug "starting $scriptname $subcmd_name" \
    || info "** starting DRY RUN $scriptname $subcmd_name **"

  $subcmd_func $* && {
    info "$subcmd_name:-$subcmd_def  completed normally" 0
  } || {
    e=$?
    error "Command $subcmd_name returned $e" $e
  }
}

