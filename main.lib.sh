#!/bin/sh


# Main: CLI helpers; init/run func as subcmd

main_lib_load()
{
  test -n "$subcmd_default" || subcmd_default=default
}

main_lib_init()
{
  lib_assert log std std-ht || return

  local log=; req_init_log || return
  $log info "" "Loaded main.lib" "$0"
}

main_lib_log() { req_init_log; }


# Count arguments consumed
incr_c()
{
  incr c $1
}


# Get help if exists for $section $id
try_help() # 1:section-number 2:help-id
{
  local b=
  for b in "" std
  do
    help="$( try_value $2 man_$1 $b || continue )"
    test -n "$help" || continue
    #spec="$( try_value $2 spc $b || printf "" )"
    #test -n "$spec" && {
    #  printf -- "$ $base $2\n\t$help\nUsage:\n\t$(eval echo "\"$base $spec\"")\n"
    #} || {
    #  printf -- "$ $base $2\n\t$help\n"
    #}
    printf -- "\n  $help\n"
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
  for i in $(seq 1 7)
  do
    try_help $i $1 && return 0
  done
  return 1
}

std_usage()
{
  ( try_local_func usage && $func_name ) ||
      ( try_local_func usage '' std && $func_name )
}

# Wrapper for try-help
std_man() # [Section] Id
{
  test -n "$*" || set -- man
  test $# -eq 1 && section= help_id="$1" || {
      test $# -eq 2 && section=$1 help_id="$2"
    }

  try_help "$section" "$help_id"
}

std_help()
{
  test -z "$1" && {
    std_usage
    # XXX: using compiled list of help ID since real list gets to long htd_usage
    echo ''
    echo 'Other commands: '
    other_cmds
    choice_global=1 std__help "$@"
    return
  }

  #test $# -eq 2 && section=$1 || section=1

  spc="$(try_spec $1)"
  test -n "$spc" && {
    echo "Usage: "
    echo "  $scriptname $spc"
    echo
  } || {
    printf "Help '%s %s': " "$scriptname" "$1"
  }

  echo_help $1 || {
    for func_id in "$1" "${base}__$1" "$base-$1"
    do
        htd_function_comment $func_id 2>/dev/null || continue
        htd_function_help $func_id 2>/dev/null && return 1
    done
    error "Got nothing on '$1'" 1
  }
}

# Echos variable or function name, for formats:
# <base>__<field>=.../()
# <base>_<property>__<field>=.../()
echo_local() # Subcmd [ Property [ Base ] ]
{
  test -n "$2" -o -n "$1" || return
  # XXX: box-*
  test -n "$box_prefix" || box_prefix=$(upper=0 mkvid $base  && echo $vid)
  test -n "$3" || set -- "$1" "$2" "$box_prefix"
  test -z "$1" || set -- " :$1" "$2" "$3"
  test -z "$2" || set -- "$1" "$2" "$3:"
  echo "$3$2$1" | tr '[:blank:][:punct:]' '_'
}

# Export echo-local to given env var-name
try_local_var() # Export-Var [ Subcmd [ Property [ Base ] ] ]
{
  test -n "$1" || error "var" 1
  local value="$(eval echo "\$$(echo_local "$2" "$3" "$4")")"
  test -n "$value" && {
    eval $1="$value"
  } || return $?
}

# Look for the 'spc' property on base/field, used for argument pattern spec.
# Stop after first value.
try_spec() # Subcmd Base
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
  test -n "$DEBUG" ||
    debug "try-local-func '$*' ($(echo_local "$@"))"
  try_func $(echo_local "$@") || return $?
}

get_subcmd_func()
{
  # Get default sub for base script
  test -n "$1" || {
    test -n "$subcmd" || {
      try_local_var subcmd "" default || return 12
    }
    set -- "$subcmd"
  }
  test -n "$1" || error "get-subcmd-func $subcmd" 1

  local subcmd_default= b=
  # Try script base, but also std namespace for function
  for b in $base std
  do

    # Look for subcmd ($1) in each namespace (or base, "$3").
    # $2 (property) is empty, iot. select function itself.
    # Set try_local_func args, see echo_local for sequence.
    set -- "$1" "" "$b"

    try_local_func "$@" || {

      # Try command alias
      try_local_var subcmd_alias $1 als $b && {
        #$LOG warn "main.lib" "aliased '$subcmd' sub-command to '$subcmd_alias'" >&2
        note "main.lib: aliased '$subcmd' sub-command to '$subcmd_alias'"
        test -n "$subcmd_alias" || error oops 1
        subcmd="$(echo "$subcmd_alias" | cut -d ' ' -f 1)"
        fnmatch "* *" "$subcmd_alias" &&
            subcmd_args_pre="$(echo "$subcmd_alias" | cut -d ' ' -f 2-)" ||
            subcmd_args_pre=""
        test -z "$DEBUG" || warn "main.lib: alias prefix: '$subcmd' '$subcmd_args_pre ...'"
        set -- "$(upper=0 mkvid "$subcmd" && echo $vid)" "" "$b"
      }
    }

    # Break on first existing function
    try_local_func "$@" && {
      subcmd_func="$(echo_local "$@")"
      #test "$base" = "$b" || base=$b
      return
    }
  done
  return 1
}

# Set subcmd and see if $func exists
try_subcmd()
{
  #test -z "$1" || {
  #  main_subcmd_args "$@" || {
  #    error "parsing args" $?
  #  }
  #}
  test -z "$subcmd" && subcmd=$1

  get_subcmd_func "$1" || {
    e=$?
    test -z "$subcmd" && {
      try_usage
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


try_subcmd_prefixes()
{
  test -n "$1" || set -- "$subcmd_default"
  upper=0 mkvid "$1" ; shift ;
  for p in ${subcmd_prefs}
  do
    func_exists ${p}$vid || continue
    cmd=${p}$vid
    $cmd "$@"
    return $?
  done
  error "No prefixed subcmd func for '$vid'" 1
}

try_package_action()
{
  use_cache=1 htd_scripts_run "$action" "$@"
}

try_context_actions()
{
  local action="$1" ctxts= ; shift

  while test $# -gt 0 -a "$1" != '--'
  do
      ctxts="$ctxts $1" ; shift
  done
  test "$1" != '--' || shift

  note "Ctxts: $ctxts"
  note "Args: $*"

  test -n "$(eval echo \"\$package_scripts_${action}\$package_scripts_${action}__0\")" && {
    action=$action try_package_action "$@"
    return $?
  }

  for ctx in $ctxts
  do
    upper=0 mkvid "$ctx" ; ctx_id="$vid"
    htd_ctx__${ctx_id}__${action} "$@"
    return $?
  done
  return 1
}


std_man_1__help="Echo a combined usage and command list. With argument, seek all sections for that ID. "
std_spc__help='-h|help [ID]'
std_als___h=help
std__help()
{
  test -n "$box_prefix" || box_prefix=$(mkvid $base; echo $vid)

  test -z "$1" && {

    lib_load functions

    # Generic help (no args)
    try_exec_func ${box_prefix}__usage $1 || { std__usage $1; echo ; }
    try_exec_func ${box_prefix}__commands || { std__commands; echo ; }
    try_exec_func ${box_prefix}__docs || true

  } || {

    # Specific help (subcmd, maybe file-format other doc, or a TODO: group arg)
    spc="$(try_spec $1)"
    test -n "$spc" && {
      echo "Usage: "
      echo "  $scriptname $spc"
      echo
    }
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
  #test -n "$2" || {
  #  locate_name $base
  #  test -n "$box_lib" || box_lib "$fn"
  #  test -n "$box_lib" && set -- "$0" "$box_lib"
  #}
  # group commands per file, using sentinal line to mark next file
  local list_functions_head="# file=\$file"

  #
  trueish "$choice_global" || {
    trueish "$choice_all" || {
      local_id=$(pwd | tr '/-' '__')
      std_info "Local-ID: $local_id"
      echo 'Local commands: '$(short)': '
    }
  }

  test -z "$choice_debug" || echo "local_id=$local_id"

  local cont= file= local_file=
  list_functions_foreach "$@" | while read line
  do
    # Check sentinel for new file-name
    test "$(expr_substr "$line" 1 1)" = "#" && {
      test "$(expr_substr "$line" 1 7)" = "# file=" && {

        file="$(expr_substr "$line" 8 ${#line})"
        debug "File: $(basename "$file" .sh)"
        test -e "$file" || warn "$line" 1
        local_file="$(grealpath --relative-to="$(pwd)" "$file")"

        # XXX: test -z "$local_id" && {
        #  # Global mode: list all commands
        #    test "$BOX_DIR/$base/$local_file" = "$file" && {
        #    echo "Commands: ($local_file) "
        #  } || {
        #    echo "Commands: ($file) "
        #  }
        #} || {
        #  # Local mode: list local commands only
        #  test "$local_file" = "${local_id}.sh" && cont= || cont=true
        #}
      } || continue
    } || true

    local subcmd_func_pref=${base}_
    #echo "file=$file local-file=$local_file 0=$0"

    if trueish "$cont"; then continue; fi
    #echo "line=$line subcmd_func_pref=$subcmd_func_pref cont=$cont"

    func=$(echo $line | grep '^'${subcmd_func_pref}_ | sed 's/()//')
    test -n "$func" || continue

    func_name="$(echo "$func"| sed 's/'${subcmd_func_pref}'_//')"
    spc=

    if test "$(expr_substr "$func_name" 1 7)" = "local__"
    then
      lcwd="$(echo $func_name | sed 's/local__\(.*\)__\(.*\)$/\1/' | tr '_' '-')"
      lcmd="$(echo $func_name | sed 's/local__\(.*\)__\(.*\)$/\2/' | tr '_' '-')"
      test -n "$lcmd" || lcmd="-"
      #spc="* $lcmd ($lcwd)"
      spc="* $lcmd "
      descr="$(eval echo \"\$${subcmd_func_pref}man_1__$func_name\")"
    else
      spc="$(eval echo \"\$${subcmd_func_pref}spc__$func_name\")"
      descr="$(eval echo \"\$${subcmd_func_pref}man_1__$func_name\")"
    fi
    test -n "$spc" || spc=$(echo $func_name | tr '_' '-' )

    test -n "$descr" || {
      grep -q "^${subcmd_func_pref}${func_name}()" "$file" && {
        descr="$(func_comment "$subcmd_func_pref$func_name" "$file")"
      } || true
    }
    test -n "$descr" || descr=".." #  TODO: $func_name description"

	  fnmatch *?"\n"?* "$descr" &&
	    descr="$(printf -- "$descr" | head -n 1)"

    test ${#spc} -gt 20 && {
      printf "  %-18s\n                      %-50s\n" "$spc" "$descr"
    } || {
      printf "  %-18s  %-50s\n" "$spc" "$descr"
    }
  done
}


std_als___V=version
std_man_1__version="Version info"
std_spc__version="-V|version"
std__version()
{
  test -n "$scriptpath" || exit 11
  test -n "$version" || exit 157
  echo "$(cat $scriptpath/.app-id)/$version"
}


# Find shell script location with or without extension.
# locate-name [ NAME || $scriptname ] [ .sh ]
# :fn
locate_name()
{
  test -n "$1" || set -- "$scriptname" "$2"
  test -n "$2" || set -- "$1" .sh
  test -n "$1" || error "locate-name: script name required" 1
  # Test with and without extension
  fn="$(which "$1")"
  test -n "$fn" || fn="$(which "$1$2")"
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

main_subcmd_alias() # Target-Var Cmd-Id
{
  try_local_var $1_alias $(echo "$2" | tr '-' '_') als \
    || try_local_var $1_alias $(echo "$2" | tr '-' '_') als std
}

# Parse some random stuff, define vars for any short/long opt
main_options_v()
{
  while test -n "$1"
  do
    case "$1" in
      --yaml ) format_yaml=1 ;;
      --interactive ) choice_interactive=1 ;;
      --non-interactive ) choice_interactive=0 ;;
      * ) trueish "$define_all" && {
          define_var_from_opt "$1"
        } || {
          error "unknown option '$1'" 1
        };;
    esac
    shift
  done
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
      return 2
      ;;

    esac
  done
  c=$(( $OPTIND -1 ))
}

# FIXME: this is getting a bit long. Split off box flags. Add subcmd opt parsing.
main_subcmd_args()
{
  local sc=0 tc=$c opt=

  while test $# -gt 0
  do case "$1" in
    -|-- ) break ;; # Stop at first std '-' arg or '--' separator
    FIXME-* )

      # BUG: -ne wont work, -en will. Should always split flags here.

      # Cut to single option '-X'
      opt="$(expr_substr "$1" 1 2 )"
      main_subcmd_alias subcmd "$opt" && {

          # Shortopt is a sub-cmd alias
          subcmd=$subcmd_alias
          flag="$1"
          shift 1
          flags="-$(expr_substr "$flag" 3 ${#flag})"
          test "$flags" = "-" && {
            incr sc
            continue
          } || {
            set -- "-$(expr_substr "$flag" 3 ${#flag})" "${1+$@}"
          }

      } || {

          # Shortop is not an sub-cmd alias, pass it on to subcmd
          true
      }

      # parse_box_subcmd_opts $* && {
      #  test $c -gt 0 && {
      #    sc=$(( $c + $sc )); shift $c ; c=0;
      #    continue
      #  }
      #} || { r=$?
      #  test $r -eq 1 && continue
      #  error "unparsable opt? $1 from '$*' returns '$r'"
      #}
      ;;

    * )
      test -z "$subcmd" && {

        subcmd=$1

      } || {
          break

        # XXX: make more flexible commands by scanning for more command name parts?
      #  try_exec_func ${base}_init_args_$subcmd $* && {

      #    test $c -gt 0 && {
      #      sc=$(( $c + $sc )); shift $c ; c=0;
      #      continue
      #    }

      #  } || {

      #    # XXX note "subcmd should parse $*"
      #    break
      #  }
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
    $LOG warn "main.lib" "Aliased '$subcmd' sub-command to '$subcmd_alias'" >&2
    cmd_name=$cmd_alias
    eval ${1}_alias=$cmd_alias
  }

  eval ${1}_func=$(echo "${func_pref}${cmd_name}${func_suf}" | tr '-' '_')
}

# set ${1}_name to cmd-function
get_cmd_func()
{
  local func_pref= func_suf= tag=

  # get extra function name parts
  for tag in pref suf; do
    # allow empty setting
    sh_isset ${1}_func_${tag} && {
      eval func_${tag}=$(eval echo \$${1}_func_${tag})
      debug "set func_${tag} for ${1} to $(eval echo \$func_${tag})"
    }
  done

  # get cmd_name
  test -n "$(eval echo \$${1})" || eval ${1}=$(eval echo \$${1}_def)

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

  {
      stdio_type 0 $$ &&
      stdio_type 1 $$ &&
      stdio_type 2 $$
  } || return

  #std_info "Verbosity $verbosity"
  sh_isset verbosity || verbosity=6

  #test -n "$scsep" || scsep=__

  return 0
}


# Run any load routines, pass it subcmd args
load_subcmd() #  Box-Prefix [Argv]
{
  test -n "$1" || error "main-load argument expected" 1
  local box_prefix="$1" r= ; shift
  try_exec_func std_load && {
    debug "Standard load OK"
  } || true # { r=$? error "std load failed"; return $r; }
  try_exec_func ${box_prefix}_load "$@" && {
    debug "Load $box_prefix OK"
  } || {
    test -z "$r" || {
      test $r -eq 0 || error "std and ${box_prefix} load failed" 1
    }
  }
}

# FIXME: two loaders std+base is not used anywhere
std_load()
{
    true
}

std_unload()
{
    true
}

# Run any load routines
main_unload()
{
  test -n "$1" || error "main-unload argument expected" 1

  local b=
  for b in "$1" "std"
  do
    try_local_func "" "unload" "$b" && {
      $(echo_local "" unload $b) || return $?
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



main_run_subcmd()
{
  local e= c=0 \
    subcmd= subcmd_alias= subcmd_func= \
    dry_run= silence= choice_force= \
    choice_all= choice_local= choice_global= \
    stdio_0_type= stdio_1_type= stdio_2_type=

  main_init

  #func_exists ${base}_parse_subcmd_args

  test -n "$box_prefix" || box_prefix=$(mkvid $base; echo $vid)

  main_subcmd_args "$@" || {
    error "parsing args" $?
  }
  test $c -gt 0 && shift $c ; c=0

  #main_debug $*

  #box_lib="$(box_list_libs "$0")"

  get_subcmd_func || {
    debug "no such subcmd-func $subcmd_func"
    try_exec_func ${base}_usage || std__usage
    test -z "$subcmd" && {
      error 'No command given' 1
    } || {
      error "No such command: $subcmd ($base)" 2
    }
  }
  test -z "$subcmd_args_pre" || set -- "$subcmd_args_pre" "$@"

  load_subcmd $box_prefix "$@" || return $?
  debug "$base loaded"

  test -z "$dry_run" \
    && debug "executing $scriptname $subcmd" \
    || std_info "** starting DRY RUN $scriptname $subcmd **"

  # Execute and exit
  $subcmd_func "$@" && {
    prev_subcmd=$subcmd
    main_unload "$box_prefix" && true || {
      error "Command $prev_subcmd failed ($?)" 4
    }

  } || {
    e=$?
    prev_subcmd=$subcmd
    main_unload $box_prefix
    error "Command $prev_subcmd returned $e" 3
  }

  test -z "$dry_run" \
    && std_info "$subcmd completed normally" 0 \
    || std_info "$subcmd dry-drun completed" 0
}


daemon()
{
  note "Running at $$"

  while read argline
  do
    main_run_subcmd "$argline" || {
      echo "?=$?"
    }
  done
}



# TODO: retrieve leading/trailing X lines, truncate to Y length
abbrev_content()
{
  echo
}



# Return path in statusdir metadata index
setup_stat()
{
  test -n "$1" || set -- .json "$2" "$3"
  test -n "$2" || set -- "$1" "${subcmd}" "$3"
  test -n "$3" || set -- "$1" "$2" "${base}"
  test -n "$1" -a -n "$2" -a -n "$3" || error "empty arg(s)" 1
  statusdir.sh assert $2$1 $3 || return $?
}


stat_key()
{
  test -n "$1" || set -- stat
  mkvid "$(pwd)"
  eval $1_key="$hnid:${base}-${subcmd}:$vid"
}

# Write/Parse simple line protocol from main_bg instance at main_sock
main_bg_writeread()
{
  printf -- "$@\r\n" | socat -d - "UNIX-CONNECT:$main_sock" \
    2>&1 | tr "\r" " " | while read line
  do
    case "$line" in
      *" OK " )
          return
        ;;
      "? "* )
          return 1
        ;;
      "!! "* )
          error "$line"
          return 1
        ;;
      "! "*": "* )
          return $(echo $line | sed 's/.*://g')
        ;;
    esac
    echo $line
  done
}

run_check()
{
  fnmatch ":*" "$1" && {
    set -- "$base$1"
  } || {
    fnmatch "-*" "$1" || {
      fnmatch "sh*" "$1" || {
        set -- "sh:$1"
      }
    }
  }

  s= p= subcmd_prefs=${base}_check_ try_subcmd_prefixes "$1"

  return $?

#    check:
#      # - htd vcflow check-doc
#      - verbosity=1 git-versioning check
#      - projectdir.sh run :bats:specs
#      - ./vendor/bin/behat --dry-run --strict
#      #- projectdir.sh run :git:status
#      - SCR_SYS_SH=bash-sh
#      - scriptname="check-includes"
#      - . ./tools/sh/init.sh
#      - . ./tools/sh/env.sh
#      - . ./tools/ci/parts/init.sh
#      - . ./tools/ci/check-env.sh
#
#    check-rst:
#      - . ~/.pyvenv/htd/bin/activate ;
#        git ls-files | grep '\.rst$' | while read rst ; do
#          rst2pseudoxml.py --report=4 --halt=4 --exit-status=2 $rst /dev/null;
#        done

#  local pwd="$(pwd -P)" ppwd="$(pwd)" spwd=. scm= scmdir=
#  vc_getscm && {
#    cd "$(dirname "$scmdir")"
#    vc_clean "$(vc_dir)"
#  }
}

# For commands that always work relative to a basedir, ie. project root;
# acquire required dir or set env with just one var
# remember starting dir and track real vs. symbolic?
push_cwd()
{
  test -n "$CWD" && {
    CWD_D=$PWD:$CWD
  }
  CWD=$PWD

  test -z "$1" || {
      fnmatch "/*" "$1" && return 1 || RCWD=$1
  }

  test -z "$RCWD" || cd $RCWD

  #test "$CWD" = "$PWD"
  #test "$CWD" = "$PCWD"

  #CWD
  #PCWD
  #RCWD
}

pop_cwd()
{
  test -z "$CWD_D" || {
    CWD="$(echo "$CWD_D" | cut -d':' -f1)"
    CWD_D="$(echo "$CWD_D" | cut -d':' -f2-)"
  }
  test -n "$CWD_D" || unset CWD_D

  test -z "$CWD" || {
    cd "$CWD"
    unset CWD
  }
}
