#!/bin/sh

set -e


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
  local func_pref="$subcmd_func_pref"
  help_descr="$(eval echo "\$${func_pref}man_$(echo $1)$(echo $2)")"
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

try_local()
{
  test -n "$1" || error "try_local:1" 1
  test -n "$2" && {
    test -z "$3" || set -- "$1" "$2${3}_"
  } || {
    test -n "$3" \
      && set -- "$1" "_${3}$scsep" \
      || set -- "$1" "$scsep"
  }
  echo "${subcmd_pref}$2$1" | tr '-' '_'
}

try_value()
{
  local value="$(eval echo "\$$(try_local "$@")")"
  test -n "$value" || return 1
  echo $value
}

try_var()
{
  test -n "$1" || error "var" 1
  local value="$(eval echo "\$$(try_local "$2" "$3" "$4")")"
  test -n "$value" && {
    export $1="$value"
  } || return $?
}

try_spec()
{
  test -z "$2" || local subcmd_pref=$2
  try_value $1 "" spc
}

try_func()
{
  type $1 >/dev/null 2>&1 && {
    func_exists=1
  } || return 1
}

try_subcmd_func()
{
  test -n "$subcmd" || subcmd=$def_subcmd
  test -n "$subcmd" || error "no cmd or default" 1
  func="$(try_local "$subcmd")"
  try_func $func || return $?
}

# Set and see if $func exists
try_subcmd()
{
  try_subcmd_func || {
    e=$?
    test -z "$subcmd" && {
      pd__usage
      error 'No command given, see "help"' 1
    } || {
      test "$e" = "1" -a -z "$func_exists" && {
        pd__usage
        error "No such command: $subcmd" 1
      } || {
        error "Command $subcmd returned $e" $e
      }
    }
  }
}

std_help()
{
  local help_base=$1 ; shift 1

  test -z "$1" && {

    # Generic help (no args)
    try_exec_func ${help_base}_usage $1 || std_usage $1
    try_exec_func ${help_base}_commands || std_commands
    try_exec_func ${help_base}_docs || noop

  } || {

    # Specific help (subcmd, maybe file-format other doc, or a TODO: group arg)
    echo "Usage: "
    echo "  $base $(try_spec $1) "
    printf "Help '$1': "
    echo_help "$1" || error "no help '$1'"
  }
}

std_usage()
{
  test -z "$1" && {
    echo "$scriptname.sh Bash/Shell script helper"
    echo 'Usage:'
    echo "  $scriptname <cmd> [<args>..]"
  } || {
    printf "$scriptname $1: "
  }
}

std_commands()
{
  test -n "$1" || set -- "$0" "$box_lib"

  # group commands per file, using sentinal line to mark next file
  local list_functions_head="# file=\$file"

  #
  test -z "$choice_global" && {
    test -z "$choice_all" && {
      local_id=$(pwd | tr '/-' '__')
      echo 'Local commands: '$(short)': '
    }
  } || {
    noop
  }

  test -z "$choice_debug" || echo "local_id=$local_id"

  local cont=
  list_functions "$@" | while read line
  do
    test "$(expr_substr "$line" 1 1)" = "#" && {
      test "$(expr_substr "$line" 1 7)" = "# file=" && {
        eval $(expr_substr "$line" 2 $(( ${#line} - 1 )))
        X=${BOX_DIR}/${base}/
        local_file=$(expr_substr "$file" $(( 1 + ${#X} )) $(( ${#file} - ${#X} )))
        test -z "$local_id" && {
          # Global mode: list all commands
            test "$BOX_DIR/$base/$local_file" = "$file" && {
            echo "Commands: ($local_file) "
          } || {
            echo "Commands: ($file) "
          }
        } || {
          # Local mode: list local commands only
          test "$local_file" = "${local_id}.sh" && cont= || cont=true
        }
      } || continue
    }
    #echo "line=$line subcmd_func_pref=$subcmd_func_pref cont=$cont"
    #echo "file=$file local-file=$local-file 0=$0"
    if test -n "$cont"; then continue; fi

    func=$(echo $line | grep '^'${subcmd_func_pref} | sed 's/()//')
    test -n "$func" || continue

    func_name="$(echo "$func"| sed 's/'${subcmd_func_pref}'//')"
    spc=
    if test "$(expr_substr "$func_name" 1 7)" = "local__"
    then
      lcwd="$(echo $func_name | sed 's/local__\(.*\)__\(.*\)$/\1/' | tr '_' '-')"
      lcmd="$(echo $func_name | sed 's/local__\(.*\)__\(.*\)$/\2/' | tr '_' '-')"
      test -n "$lcmd" || lcmd="-"
      #spc="* $lcmd ($lcwd)"
      spc="* $lcmd "
      descr="$(eval echo "\$${subcmd_func_pref}man_1_$func_name")"
    else
      spc="$(eval echo "\$${subcmd_func_pref}spc_$func_name")"
      descr="$(eval echo "\$${subcmd_func_pref}man_1_$func_name")"
    fi
    test -n "$spc" || spc=$(echo $func_name | tr '_' '-' )
    test -n "$descr" || {
      grep -q "^${subcmd_func_pref}${func_name}()" $file && {
        descr="$(func_comment $subcmd_func_pref$func_name $file)"
      } || noop
    }
    printf "  %-25s  %-50s\n" "$spc" "$descr"
  done
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

parse_subcmd_valid_flags()
{
  local flag=$1
  shift 1
  test -z "$*" && {
    test -z "$subcmd" || {
      error "'$subcmd' does not accept -$flag" 1
    }
  }
  fnmatch "*$subcmd*" "$*" || {
    error "'$subcmd' does not accept -$flag" 1
  }
  case $subcmd in
      init ) case $flag in c ) return;; esac ;;
      create ) case $flag in i ) return;; esac ;;
  esac
  return 1
}

get_cmd_alias()
{
  local func_pref="$(eval echo \$${1}_func_pref)"
  export ${1}_alias=$(eval echo \$${func_pref}als$(echo "_$2" | tr '-' '_'))
}

parse_box_subcmd_opts()
{
  local o=
  while getopts fagvqsn o
  do
    case "$o" in

    #r ) subcmd=run;;
    #n ) subcmd=new;;
    #h ) subcmd=help;;
    i ) parse_subcmd_valid_flags $o init create; subcmd=init;;
    c ) parse_subcmd_valid_flags $o init create; subcmd=create;;
    #d ) subcmd=deinit;;

    f ) parse_subcmd_valid_flags $o new; choice_force=true;;
    a ) parse_subcmd_valid_flags $o list; choice_all=true;;
    g ) parse_subcmd_valid_flags $o run init edit; choice_global=true;;
    l ) parse_subcmd_valid_flags $o; choice_local=true;;
    d ) parse_subcmd_valid_flags $o; choice_debug=true;;

    n ) dry_run=true ;;
    s ) silence=true; verbosity=0;;
    #S ) silence=$OPTARG;;
    v ) test $silent || verbosity=$(( $verbosity + 1 ));;
    q ) test $verbosity -ne 0 || silence=7; verbosity=0;;

    [?] )
      #echo "Error $o"
      #print >&2 "Usage: $0 [-s] [-d seplist] file ..."
      return 2
      ;;

    esac
  done
  c=$(( $OPTIND -1 ))
}

# FIXME: this is getting a bit long. Split off box flags. Add subcmd opt parsing.
get_subcmd_args()
{
  local sc=0 tc=$c

  while [ $# -gt 0 ]
  do  case "$1" in

    -|-- )
      break
      ;;

    --* )
      error "no long options $1" 1
      ;;

    -* )

      # BUG: -ne wont work, -en will. Should always split flags here.
      get_cmd_alias subcmd "$(expr_substr "$1" 1 2 )"
      test -n "$subcmd_alias" && {
        subcmd=$subcmd_alias
        flag="$1"
        shift 1
        flags="-$(expr_substr "$flag" 3 ${#flag})"
        test "$flags" = "-" && {
          incr sc
          continue
        } || {
          set --  "-$(expr_substr "$flag" 3 ${#flag})" "${1+$@}"
        }
      } || noop

      parse_box_subcmd_opts $* && {
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
      test -z "$subcmd" && {

        subcmd=$1

      } || {

        # XXX
        try_exec_func ${base}_init_args_$subcmd $* && {

          test $c -gt 0 && {
            sc=$(( $c + $sc )); shift $c ; c=0;
            continue
          }

        } || {

          # XXX note "subcmd should parse $*"
          break
        }
      }
      ;;

    esac

    incr sc
    shift

  done

  c=$tc
  test $sc -eq 0 || {
    c=$(( $c + $sc ))
  }
}

get_cmd_func_name()
{
  # XXX 'local' seems better than 'eval'
  # set don't work that good or using it wrong. No declare, typeset.
  #echo ${func_pref} $(eval echo \${${1}_name}) ${func_suf}
  #echo ${1}_func=$(eval echo "${func_pref}\${${1}_name}${func_suf}" | tr '-' '_')
  # FIXME: test this.
  export ${1}_func=$(eval echo "${func_pref}\${${1}}${func_suf}" | tr '-' '_')
}

# set ${1}_name to cmd-function
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

  # get cmd_name
  test -n "$(eval echo \$${1})" || export ${1}=$(eval echo \$${1}_def)

  get_cmd_func_name $1

  unset func_pref func_suf tag
}


# Setup some initial vars and load lib files for main script
main_init()
{
  test -n "$1" || set -- "$base"

  stdio_type 0 $$
  stdio_type 1 $$
  stdio_type 2 $$

  var_isset verbosity || verbosity=6

  test -n "$scsep" || scsep=__
}

box_init()
{
  box_src="$(dry_run= box_list_libs $0 $1 | while read src path args; \
    do eval echo $path; done)"
  box_lib="$box_src"
}


# Parse command line arguments and set subcmd vars
main_parse_subcmd()
{
  c=0
  #func_exists ${base}_parse_subcmd_args
  get_subcmd_args "$@"
  get_cmd_func subcmd
}


# Run any load routines
main_load()
{
  local r=
  try_exec_func load || {
    # f
    r=$?; test -n "$1" || {
      test $1 -eq 0 || error "std load failed" $r
    }
  }
  test -n "$1" || return
  try_exec_func ${1}_load || {
    test -z "$r" || {
      test $r -eq 0 || error "std and ${1} load failed" 1
    }
  }
}

main_debug()
{
  debug "vars:
    cmd=$base args=$*
    subcmd=$subcmd subcmd_alias=$subcmd_alias subcmd_def=$subcmd_def
    script_name=$script_name script_subcmd=$script_subcmd
    subcmd_func=$subcmd_func subcmd_func_pref=$subcmd_func_pref subcmd_func_suf=$subcmd_func_suf

    silent=$silent silence=$silence verbosity=$verbosity
    choice_local=$choice_local choice_global=$choice_global
    choice_all=$choice_all
    choice_force=$choice_force
  "
}



#  local scriptname= base=

#  local subcmd_def=
#  local subcmd_pref= subcmd_suf=
#  local subcmd_func_pref= subcmd_func_suf=

run_subcmd()
{
  local e= c=0 box_lib= \
    subcmd= subcmd_alias= subcmd_func= \
    dry_run= silence= choice_force= \
    choice_all= choice_local= choice_global= \
    stdio_0_type= stdio_1_type= stdio_2_type=

  main_init

  main_parse_subcmd "$@"
  test $c -gt 0 && shift $c ; c=0
  main_debug $*

  main_load $base
  debug "$base loaded"

  func_exists $subcmd_func || {
    debug "no such subcmd-func $subcmd_func"
    try_exec_func ${base}_usage || std_usage
    test -z "$subcmd" && {
      error 'No command given' 1
    } || {
      error "No such command: $subcmd" 2
    }
  }

  test -z "$dry_run" \
    && debug "executing $scriptname $subcmd" \
    || info "** starting DRY RUN $scriptname $subcmd **"

  $subcmd_func "$@" && {
      test -z "$dry_run" \
        && info "$subcmd completed normally" 0 \
        || info "$subcmd dry-drun completed" 0
  } || {
    e=$?
    error "Command $subcmd returned $e" 3
  }
}

req_htdir()
{
  test -n "$HTDIR" -a -d "$HTDIR" || return 1
}


daemon()
{
  note "Running at $$"

  while read argline
  do
    run_subcmd "$argline" || {
      echo "?=$?"
    }
  done
}

