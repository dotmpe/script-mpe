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
  local b=
  for b in "" std
  do
    try_value $2 man_$1 $b || continue
    return
  done
  return 1
}

# Run through all help sections for given string, echo and return on first
# 1:str
# :
echo_help()
{
  #try_exec_func ${help_base}__usage $1 || std__usage $1
  # Man sections:
  # 1. (user) commands
  # (2. System calls)
  # (3. C Library Fuctions)
  # 4. Devices and special files
  # 5. File formats and conventions
  # 6. Games et. Al.
  # 7. Miscellenea (overview, conventions, misc.)
  # 8. SysAdmin tools and Daemons
  try_help 1 $1 && return 0 || \
  try_help 5 $1 && return 0 || \
  try_help 7 $1 && return 0
  return 1
}

# try_local subcmd [property [base]]
# echos variable or function name
try_local()
{
  test -n "$2" -o -n "$1" || return
  test -n "$local_prefix" || local_prefix=$(mkvid $base ; echo $vid)
  test -n "$3" || set -- "$1" "$2" "$local_prefix"
  test -z "$1" || set -- " :$1" "$2" "$3"
  test -z "$2" || set -- "$1" "$2" "$3:"
	echo "$3$2$1" | tr '[:blank:][:punct:]' '_'
}

try_value()
{
  local value="$(eval echo "\$$(try_local "$@")")"
  test -n "$value" || return 1
  echo $value
}

try_local_var()
{
  test -n "$1" || error "var" 1
  local value="$(eval echo "\$$(try_local "$2" "$3" "$4")")"
  test -n "$value" && {
    export $1="$value"
  } || return $?
}

try_spec()
{
  local b=
  for b in "$2" "std"
  do
    try_value "$1" "spc" "$b" || continue
    return
  done
  return 1
}

try_func()
{
  type $1 >/dev/null 2>&1 && {
    func_name=$1
    func_exists=1
  } || return 1
}

try_local_func()
{
  try_func $(try_local "$@") || return $?
}

get_subcmd_func()
{
  test -n "$local_prefix" || local_prefix=$(mkvid $base; echo $vid)

  # Get default sub for base script
  test -n "$1" || {
    test -n "$subcmd" || {
      try_local_var subcmd "" default || return 12
    }
    set -- "$subcmd"
  }

  # Look in local and std namespace

  local subcmd_default= b=

  for b in "" std
  do
    set -- "$1" "" "$b"

    try_local_func "$@" || {
      # Try command alias
      try_local_var cmd_als $1 als $b
      test -z "$cmd_als" || \
        set -- "$(mkvid "$cmd_als";echo $vid)" "" "$b"
    }

    try_local_func "$@" && {
      subcmd_func="$(try_local "$@")"
      return
    }
  done
}


# Set and see if $func exists
try_subcmd()
{
  test -z "$1" || {
    get_subcmd_args "$@" || {
      error "parsing args" $?
    }
  }
  get_subcmd_func || {
    e=$?
    test -z "$subcmd" && {
      ( try_local_func usage && $func_name ) \
        || ( try_local_func usage '' std && $func_name )
      error 'No command given, see "help"' 1
    } || {
      test "$e" = "1" -a -z "$func_exists" && {
        ( try_local_func usage || try_local_func usage '' std ) && {
          $func_name
        }
        error "No such command: $subcmd" 1
      } || {
        error "Command $subcmd returned $e" $e
      }
    }
  }
}


std_man_1__help="Echo a combined usage and command list. With argument, seek all sections for that ID. "
std_spc__help='-h|help [ID]'
std_als___h=help
std__help()
{
  #local local_prefix=$subcmd_func_pref
  test -n "$local_prefix" || local_prefix=$(mkvid $base; echo $vid)

  test -z "$1" && {

    # Generic help (no args)
    try_exec_func ${local_prefix}__usage $1 || std__usage $1
    try_exec_func ${local_prefix}__commands || std__commands
    try_exec_func ${local_prefix}__docs || noop

  } || {

    # Specific help (subcmd, maybe file-format other doc, or a TODO: group arg)
    echo "Usage: "
    echo "  $base $(try_spec $1) "
    printf "Help '$1': "
    echo_help "$1" || error "no help '$1'"
  }
}

std__usage()
{
  test -z "$1" && {
    echo "$scriptname.sh Bash/Shell script helper"
    echo 'Usage:'
    echo "  $scriptname <cmd> [<args>..]"
  } || {
    printf "$scriptname $1: "
  }
}

std__commands()
{
  test -n "$1" || set -- "$0" "$box_lib"

  # group commands per file, using sentinal line to mark next file
  local list_functions_head="# file=\$file"

  #
  trueish "$choice_global" || {
    trueish "$choice_all" || {
      local_id=$(pwd | tr '/-' '__')
      echo 'Local commands: '$(short)': '
    }
  }

  test -z "$choice_debug" || echo "local_id=$local_id"

  local cont=
  list_functions "$@" | while read line
  do

    # Check sentinel
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

    local subcmd_func_pref=${base}__
    #echo "file=$file local-file=$local-file 0=$0"
    if trueish "$cont"; then continue; fi
    #echo "line=$line subcmd_func_pref=$subcmd_func_pref cont=$cont"

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


std_als___V=version
std_man_1__version="Version info"
std_spc__version="-V|version"
std__version()
{
	test -n "$scriptdir" || exit 156
	test -n "$version" || exit 157
  echo "$(cat $scriptdir/.app-id)/$version"
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
  try_local_var $1_alias $(echo "$2" | tr '-' '_') als \
    || try_local_var $1_alias $(echo "$2" | tr '-' '_') als std

#  local func_pref="$(eval echo \$${1}_func_pref)"
#  export ${1}_alias=$(eval echo \$${func_pref}als
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
  test -n "$1" || error "get_cmd_func_name:1:varname expected" 1
  local cmd_name="$(eval echo "\$${1}")"

  local cmd_alias="$(eval echo \$${func_pref}als$(echo "_${cmd_name}" | tr '-' '_'))"
  test -z "$cmd_alias" || {
    cmd_name=$cmd_alias
    export ${1}_alias=$cmd_alias
  }

  export ${1}_func=$(echo "${func_pref}${cmd_name}${func_suf}" | tr '-' '_')
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

  test -z "$choice_debug" || {
    eval echo "get_cmd_func @='\$@' "\
      " ${1}_pref=\$${1}_pref "\
      " ${1}_suf=\$${1}_suf " \
      " ${1}_def=\$${1}_def " \
      " ${1}_alias=\$${1}_alias " \
      " ${1}=\$${1} "
  }

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

  #test -n "$scsep" || scsep=__
}

box_src_lib()
{
  box_src="$(dry_run= box_list_libs $0 $1 | while read src path args; \
    do eval echo $path; done)"
  box_lib="$box_src"
}


# Run any load routines
main_load()
{
  test -n "$1" || set -- "$local_prefix"
  local r=
  try_exec_func std_load && {
    debug "Standard load OK"
  } || noop # { r=$? error "std load failed"; return $r; }
  try_exec_func ${1}_load && {
    debug "Load $1 OK"
  } || {
    test -z "$r" || {
      test $r -eq 0 || error "std and ${1} load failed" 1
    }
  }
}

# FIXME: two loaders std+base is not used anywhere
std_load()
{
    noop
}

std_unload()
{
    noop
}

# Run any load routines
main_unload()
{
  test -n "$local_prefix" || local_prefix=$(mkvid $base; echo $vid)
  test -n "$1" || set -- "$local_prefix"

  local b=
  for b in "$1" "std"
  do
    try_local_func "" "unload" "$b" && {
      $(try_local "" unload $b) || return $?
    } || continue
    return
  done
  return

  # XXX: cleanup
  local r=
  try_exec_func std_unload && {
    debug "Standard unload OK"
  } || {
    # f
    r=$?; test -n "$1" || {
      test $1 -eq 0 || error "std unload failed" $r
    }
  }
  test -n "$1" || return
  try_exec_func ${1}_unload && {
    debug "Load $1 OK"
  } || {
    test -z "$r" || {
      test $r -eq 0 || error "std and ${1} unload failed" 1
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



run_subcmd()
{
  local e= c=0 box_lib= \
    subcmd= subcmd_alias= subcmd_func= \
    dry_run= silence= choice_force= \
    choice_all= choice_local= choice_global= \
    stdio_0_type= stdio_1_type= stdio_2_type=

  main_init

  #func_exists ${base}_parse_subcmd_args

  test -n "$box_prefix" || box_prefix=$(mkvid $base; echo $vid)
  #local_prefix=${box_prefix}__
  test -n "$local_prefix" || local_prefix=$(mkvid $base; echo $vid)

  get_subcmd_args "$@" || {
    error "parsing args" $?
  }

  #echo subcmd=$subcmd subcmd_func_pref=$subcmd_func_pref
  #echo base=$base
  #echo local_prefix=$local_prefix

  test $c -gt 0 && shift $c ; c=0
  main_debug $*

  main_load || return $?
  debug "$base loaded"

  #box_lib="$(box_list_libs "$0")"

  get_subcmd_func || {
    debug "no such subcmd-func $subcmd_func"
    try_exec_func ${base}_usage || std__usage
    test -z "$subcmd" && {
      error 'No command given' 1
    } || {
      error "No such command: $subcmd" 2
    }
  }

  test -z "$dry_run" \
    && debug "executing $scriptname $subcmd" \
    || info "** starting DRY RUN $scriptname $subcmd **"

  # Execute and exit

  $subcmd_func "$@" || {
    e=$?
    main_unload
    error "Command $subcmd returned $e" 3
  }

  main_unload || {
    error "Command $subcmd failed (unload: $?)" 4
  }

  test -z "$dry_run" \
    && info "$subcmd completed normally" 0 \
    || info "$subcmd dry-drun completed" 0
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

trueish()
{
  test -n "$1" || return 1
  case "$1" in
    on|true|yes|1)
      return 0;;
    * )
      return 1;;
  esac
}


