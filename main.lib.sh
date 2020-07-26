#!/bin/sh


# Main: CLI helpers; init/run func as subcmd

main_lib_load()
{
  test -n "${subcmd_default-}" || subcmd_default=default
}

main_lib_init()
{
  test "${main_lib_init-}" = "0" && return

  local log=; req_init_log || return
  $log info "" "Loaded main.lib" "$0"
}

main_lib_log() { req_init_log; }


# Get help if exists for $section $id
try_help() # 1:section-number 2:help-id
{
  local b=
  for b in "" std
  do
    help="$( try_value $2 man_$1 $b || continue )"
    test -n "$help" || continue
    # XXX: cleanup
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
  for i in $(seq 1 7)
  do
    try_help $i $1 && return 0
  done
  return 1
}

# Echos variable or function name, for formats:
# <base>__<field>=.../()
# <base>_<property>__<field>=.../()
echo_local() # Subcmd [ Property [ Base ] ]
{
  test -n "${2-}" -o -n "${1-}" || return
  # XXX: box-*
  test -n "${box_prefix:-}" || box_prefix=$(upper=0 mkvid $base  && echo $vid)
  test -n "${3-}" || set -- "${1-}" "${2-}" "$box_prefix"
  test -z "$1" || set -- " :$1" "$2" "$3"
  test -z "$2" || set -- "$1" "$2" "$3:"
  echo "$3$2$1" | tr '[:blank:][:punct:]' '_'
}

# Export echo-local to given env var-name
try_local_var() # Export-Var [ Subcmd [ Property [ Base ] ] ]
{
  test -n "$1" || error "var" 1
  local value="$(eval echo \"\${$(echo_local "$2" "$3" "${4-}")-}\")"
  test -n "$value" && {
    eval $1="$value"
  } || return $?
}

# Look for the 'spc' property on base/field, used for argument pattern spec.
# Stop after first value.
try_spec() # Subcmd Base
{
  local b=
  test $# -ge 1 || return
  test -n "${2-}" || set -- "$1" "$base"
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
  test -z "${DEBUG-}" || {
    $LOG debug "" "try-local-func '$*' ($(echo_local "$@"))"
  }
  try_func $(echo_local "$@") || return $?
}

main_local() # Base-Ids Attr-Id [Subs....]
{
  local v baseids="$1" attrid="$2" local
  shift 2
  test $# -gt 0 && local=__$(echo "$*" | sed 's/ /__/g') || local=
  for baseid in $baseids
  do
    echo ${baseid}_${attrid}$local
  done
}

main_var() # Base-Ids Var-Name [Default [Local]]
{
  local v baseids="$1" varid="$2" default="${3-"default"}" local
  test $# -gt 2 && shift 3 || shift 2
  for local in $( main_local "$baseids" "$varid" "$@" )
  do
    v="$(eval "echo \"\${$local-}\"")"
    test -n "$v" || continue
    #eval "$varid=\"$v\""
    printf -v $varid "%s" "$v"
    return
  done
  printf -v $varid "%s" "$default"
  return 1
}

# Look for function part to main-*-run
main_handle() # Base-Ids Handle-Name [Default [Local]]
{
  local f baseids="$1" hndid="$2" default="${3-"default"}" local
  test $# -gt 2 && shift 3 || shift 2
  for local in $( main_local "$baseids" "$hndid" "$@" )
  do
    test "$(type -t "$local")" = "function" || continue
    printf -v $hndid "%s" "$local"
    return
  done
  printf -v $hndid "%s" "$default"
  return 1
}

main_subcmd_func()
{
  # Get default subcmd for base
  test -n "${1-}" || {
    test -n "${subcmd-}" || {
      # main_var "$baseids" subcmd default
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
        test -z "${DEBUG-}" || warn "main.lib: alias prefix: '$subcmd' '$subcmd_args_pre ...'"
        set -- "$(upper=0 mkvid "$subcmd" && echo $vid)" "" "$b"
      }
    }

    load_groups $subcmd

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

  main_subcmd_func "$1" || {
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


# Execute first found subcmd handle
try_subcmd_prefixes()
{
  test -n "${subcmd_prefs-}" || return
  test -n "$*" || set -- "${subcmd_default-help}"
  local vid p cmd
  upper=0 mkvid "$1" ; shift ;
  for p in ${subcmd_prefs}
  do
    func_exists ${p}$vid || continue
    cmd=${p}$vid
    $cmd "$@"
    return $?
  done
  error "No prefixed subcmd func for '$vid' ($subcmd_prefs)" 1
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


# Find shell script location with or without extension.
# locate-name [ NAME || $scriptname ] [ .sh ]
# :fn
locate_name()
{
  test -n "${1-}" || set -- "$scriptname" "${2-}"
  test -n "${2-}" || set -- "$1" .sh
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
  while test $# -gt 0
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
            sc=$(( $sc + 1 ))
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

    sc=$(( $sc + 1 ))
    shift

  done

  c=$tc
  test $sc -eq 0 || {
    c=$(( $c + $sc ))
  }
}

get_cmd_func_name() # SUBCMD
{
  test $# -eq 1 -a -n "${1-}" || error "get_cmd_func_name:1:varname expected" 1
  local cmd_name="$(eval echo "\$${1}")"

  local cmd_alias=
  get_cmd_alias $1

  eval ${1}_func=$(echo "${func_pref}${cmd_name}${func_suf}" | tr '-' '_')
}

get_cmd_alias() # SUBCMD
{
  cmd_alias="$(try_value ${func_pref}als$(echo "_${cmd_name}" | tr '-' '_'))"
  test -z "$cmd_alias" || {
    $LOG warn "main.lib" "Aliased '$subcmd' sub-command to '$subcmd_alias'" >&2
    cmd_name=$cmd_alias
    eval ${1}_alias=$cmd_alias
  }
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
  test -n "$(try_value ${1} )" || eval ${1}=$(eval echo \$${1}_def)

  get_cmd_func_name $1

  test -z "${choice_debug-}" || {
    eval echo "get_cmd_func @='\$@' "\
      " ${1}_pref=\$${1}_pref "\
      " ${1}_suf=\$${1}_suf " \
      " ${1}_def=\$${1}_def " \
      " ${1}_alias=\$${1}_alias " \
      " ${1}=\$${1} "
  }

  unset func_pref func_suf tag
}

load_groups() # SUBCMD
{
  local grp="$(try_value "${1}" grp ${base})"
  test ! -n "$grp" || load_group $grp
}

load_group()
{
  local libs="$(for x in "$@"; do
    test -e $scriptpath/commands/$base-$x.lib.sh && echo $base-$x || echo $x ; done)"
  lib_require $libs
  # XXX: no lib_init $libs for htd cmd groups
}


# Run load routine, pass it subcmd args
main_subcmd_load() #  Box-Prefix [Argv]
{
  test -n "$1" ||
      error "main-subcmd-load Box-Prefix argument expected" 1
  local box_prefix="$1"; shift

  func_exists ${box_prefix}_subcmd_load || return 0
  ${box_prefix}_subcmd_load "$@" || return
  $LOG debug "" "Load $box_prefix OK"
}

# Run unload routine
main_subcmd_unload() # Box-Prefix
{
  test -n "$1" ||
      error "main-subcmd-unload Box-Prefix argument expected" 1

  func_exists ${1}_subcmd_unload || return 0
  ${1}_subcmd_unload || return
  $LOG debug "" "Unload $1 OK"
}

main_run_subcmd()
{
  local e= c=0 \
    subcmd= subcmd_alias= subcmd_func= \
    dry_run= silence= choice_force= \
    choice_all= choice_local= choice_global=

  box_prefix="$base"
  # true "${box_prefix:="$(mkvid $base; echo $vid)"}"

  main_subcmd_args "$@" || {
    error "parsing args" $?
  }
  test $c -gt 0 && shift $c ; c=0

  #test -n "${box_lib-}" -o -z "${ENV_SRC-}" || box_lib="$(eval "echo $ENV_SRC")"
  #box_lib="$(box_list_libs "$0")"

  main_subcmd_func || {
    $LOG debug '' "No such subcmd-func '$scriptname:$subcmd' <$subcmd_func> ($base)"
    try_exec_func ${base}_main_usage || std__usage
    test -z "$subcmd" && {
      $LOG error '' 'No command given' 1
    } || {
      $LOG error '' "No such command: '$scriptname:$subcmd'" 2
    }
  }
  test -z "${subcmd_args_pre-}" || set -- "$subcmd_args_pre" "$@"

  # XXX: main_subcmd_load "$baseids" "$@" || return $?
  main_subcmd_load $box_prefix "$@" || return $?
  test -z "${DEBUG-}" || debug "Base '$base $subcmd' loaded"

  test -z "$dry_run" \
    && {
      test -z "${DEBUG-}" || debug "Executing '$scriptname:$subcmd'"
    } || std_info "** starting DRY RUN '$scriptname:$subcmd' **"

  # Execute and exit
  $subcmd_func "$@" && {
    prev_subcmd=$subcmd
    main_subcmd_unload "$box_prefix" && true || {
      error "Command '$scriptname:$prev_subcmd' failed ($?)" 4
    }

  } || {
    e=$?
    prev_subcmd=$subcmd
    main_subcmd_unload $box_prefix
    error "Command '$scriptname:$prev_subcmd' returned $e" 3
  }

  test -z "$dry_run" \
    && std_info "'$base-$subcmd' completed normally" 0 \
    || std_info "'$base-$subcmd' dry-drun completed" 0
}

main_subcmd_run_init()
{
  func_exists ${1}_subcmd_unload || return 0
  ${1}_subcmd_unload || return
  $LOG debug "" "Unload $1 OK"
}

main_subcmd_run ()
{
  local main=${main-"subcmd"} c r group
  main_var "${baseids:="$base"}" group "" || true

  # Pre-load env needed to bootstrap and run subcmd handler
  main_handle "$baseids" run_init main_${main}_init || true

  local c= subcmd
  $run_init "$@" || return

  main_${main}_run_init "$baseids" "$@" || return
  test $c -gt 0 && shift $c ; c=0

  main_${main}_run_load "$baseids" "$@" || return

  $subcmd_func "$@"

  main_${main}_run_unload "$baseids" "$c"

  echo 1: $make_main
  echo 2: $baseids
  echo 3: $group
  return
}

# TODO: make main_subcmd_run load contexts?
#xtestmake_subcmd_init()
#xtest_subcmd_init()
#std_subcmd_init()

main_subcmd_init()
{
  test -n "${1-}" || set -- $subcmd_default
  echo main_handle "$baseids" "$1" || return
  main_local "$baseids" "$1" || return
  main_handle "$baseids" "$1" || return
  c=1
  subcmd="$(eval echo \"\$$1\")"
#
#  try_local_func "$subcmd" && {
#    subcmd_func="$(echo_local "$@")"
#  } || return
}

main_subcmd_run_load()
{
  echo main_subcmd_run_load $*
}

main_subcmd_run_unload()
{
  echo main_subcmd_run_unload $*
}

# Take semi-bootstrapped shell and start executable script
main_run_static () # Base(s) Argv...
{
  test -n "${1-}" || return

  test $(test -t "lib_load") = function || {
    U_S=/srv/project-local/user-scripts
    . $U_S/src/sh/lib/lib.lib.sh
    . $U_S/src/sh/lib/lib-util.lib.sh
  }
  test $(test -t "lib_load") = function || {
    . $HOME/bin/str-htd.lib.sh && str_htd_lib_load && str_htd_lib_loaded=$?

  }

  local base bases="$1" baseids main= main_run; shift;
  baseids="$(for base in $bases;
      do mknameid $base && echo $nameid ; done)"

  # Prepare to defer to main-*-run defined by <base>_main
  main_var "$baseids" main subcmd || true
  main_run="main_$(echo "$main" | tr '-' '_')_run"

  local scriptname=$(basename "$0")
  $main_run $*
}

daemon()
{
  note "Running at $$"

  while read argline
  do
    main_subcmd_run "$argline" || {
      echo "?=$?"
    }
  done
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

# Look if ENV name starts with 'dev'
main_isdevenv()
{
  test -n "${ENV_DEV-}" || {
    fnmatch "dev*" "${ENV-}" && ENV_DEV=1 || ENV_DEV=0
  }
  trueish "$ENV_DEV"
}
