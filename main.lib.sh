#!/bin/sh


# Main: CLI helpers; init/run func as subcmd

main_lib__load()
{
  test -n "${subcmd_default-}" || subcmd_default="default-main"
}

main_lib__init()
{
  test -z "${main_lib_init-}" || return $_

  req_init_log || return
  $us_log info "" "Loaded main.lib" "$0"
  #! sys_debug -dev -debug -init ||
  #  $LOG notice "" "Initialized main.lib" "$(sys_debug_tag)"
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
  test -n "${3-}" || {
    # XXX: cleanup box-*
    test -n "${box_prefix:-}" || box_prefix=$(upper=true str_word "$base")
    set -- "${1-}" "${2-}" "$box_prefix"
  }
  test -z "$1" || set -- "__$1" "$2" "$3"
  test -z "$2" || set -- "$1" "$2" "$3_"
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
    $us_log debug "" "try-local-func '$*' ($(echo_local "$@"))"
  }
  try_func $(echo_local "$@") || return $?
}

main_local () # Base-Ids [Attr-Id [Fields....]]
{
  test $# -gt 0 -a -n "${1-}" || return
  #shellcheck disable=2316 # I can use $local, so I do
  local baseids="$1" attrid= local baseid; shift
  test -z "${1-}" || attrid=_$1; shift
  test $# -eq 0 && local= || local=$( while test $# -gt 0
      do printf '__%s' "$1"; shift; done )
  for baseid in $baseids
  do
    echo ${baseid}${attrid}$local
  done | tr '[:blank:][:punct:]' '_'
}

main_value () # Base-Ids Attr-Id [Default [Fields....]]
{
  #shellcheck disable=2316 # I can use $local, so I do
  local baseids="$1" attrid="$2" default="${3-"default"}" local v
  test $# -gt 2 && shift 3 || shift 2
  for local in $( main_local "$baseids" "$attrid" "$@" )
  do
    v=${!local-} || continue
    test -n "$v" || continue
    echo "$v"
    return
  done
  test -z "$default" || echo "$default"
  return 1
}

# Look for variable <base>[-<attr>]--<field[--field...]>
main_var () # Var-Name Base-Ids Attr-Id [Default [Local]]
{
  local varid=$1 v; shift
  v="$( main_value "$@" )" && {
    printf -v $varid "%s" "$v"
    return
  }
  printf -v $varid "%s" "$v"
  return 1
}

# TODO: redesign @Dsgn
try_var()
{
  local value=
  eval "value=\"\$$1\"" >/dev/null 2>/dev/null
  test -n "$value" || return 1
  echo $value
}

# Get echo-local output, and return 1 on empty value. See echo-local spec.
try_value()
{
  local value=
  test $# -gt 1 && {
    value="$(eval echo "\"\${$(echo_local "$@")-}\"" || return )"
  } || {
    value="$(eval echo \"\${${1-}-}\" || return )"
  }
  test -n "$value" || return 1
  echo "$value"
}

# Look for function part <base>[-<attr>]--<field[--field...]>
main_func () # Var-Name Base-Ids Attr-Name [Default [Local...]]
{
  #shellcheck disable=2316 # I can use $local, so I do
  local varname="$1" baseids="$2" attrid="$3" default="${4-"default"}" local
  test $# -gt 3 && shift 4 || shift 3
  for local in $( main_local "$baseids" "$attrid" "$@" )
  do
    test "$(type -t "$local")" = "function" || continue
    printf -v $varname "%s" "$local"
    return
  done
  printf -v $varname "%s" "$default"
  return 1
}

# Look for function part to main-*-run
main_handle () # Base-Ids Handle-Name [Default [Local...]]
{
  main_func "$2" "$@"
}

# Subcmd_func after loading groups and resolving alias
main_subcmd_func () # Subcmd
{
  main_subcmd_alias "$1" && { set -- $subcmd; }
  : "${subcmd_group:="$( main_value "$baseids" "grp" "" "$1" )"}"
  test -z "$subcmd_group" || {
    main_subcmd_func_load $subcmd_group || return
  }
  main_func "subcmd_func" "$baseids" "" "" "$1"
}

main_subcmd_alias ()
{
  : "${subcmd_alias:="$( main_value "$baseids" "als" "" "$1" )"}"
  test -z "$subcmd_alias" && return 1
  $us_log debug "" "Resolved '$1' alias to '$subcmd_alias'"
  subcmd=$subcmd_alias
  subcmd_alias=$1
}

# Recursively load libraries for subcmds
main_subcmd_func_load () # ~ <Groups...>
{
  main_groups_load "$@" || {
    $us_log error "" "Loading groups for '$1'" "$subcmd_group"
    return 1
  }

  local group supergroups
  for group in "$@"
  do
      main_var supergroups "$baseids" "grp" "" "$1" || continue
      main_subcmd_func_load $( for x in $supergroups; do
        fnmatch "* $x *" " $lib_loaded " && continue; echo $x; done )
  done
}

main_groups_load () # ~ <Groups...>
{
  local grp name libs
  for grp in "$@"
  do
    for name in $base-$grp $grp
    do
      lib_exists "$name" >/dev/null && libs=${libs:-}${libs:+ }$name || continue
    done
  done
  test -z "${libs:-}" && return
  lib_require $libs
  test 0 -eq $? &&
      $us_log info "" "Sourced libs for groups" "$*:$libs" ||
      $us_log warn "" "Sourced libs for groups" "E$_:$*:$libs" $_
}

# Execute first found subcmd handle
try_subcmd_prefixes()
{
  test -n "${subcmd_prefs-}" || return
  test -n "$*" || set -- "${subcmd_default:-"help"}"
  local pref p cmd
  str_vword pref "$1"
  shift
  for p in ${subcmd_prefs}
  do
    func_exists "${p}$pref" || continue
    cmd=${p}$pref
    $cmd "$@"
    return $?
  done
  error "No prefixed subcmd func for '$pref' ($subcmd_prefs)" 1
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

  test -n "$(eval echo \"\$\{package_scripts_${action}-}\$package_scripts_${action}__0\")" && {
    action=$action try_package_action "$@"
    return $?
  }

  local ctx{,_id}
  for ctx in $ctxts
  do
    str_vword ctx_id "$ctx"
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
          define_var_from_opt "$1" ${main_opts_var_name_pref:="choice_"}
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

# TODO: cleanup
#    test -z "$subcmd" && {
#      $us_log error '' 'No command given' 1
#    } || {
#      $us_log error '' "No such command: '$scriptname:$subcmd'" 2
#  test -z "${DEBUG-}" || debug "Base '$base $subcmd' loaded"
#
#  test -z "$dry_run" \
#    && {
#      test -z "${DEBUG-}" || debug "Executing '$scriptname:$subcmd'"
#    } || std_info "** starting DRY RUN '$scriptname:$subcmd' **"
#      error "Command '$scriptname:$subcmd' failed ($?)" 4

#dry_run= silence= choice_force= \
#choice_all= choice_local= choice_global=

main_subcmd_run ()
{
  local main=${main-"subcmd"} r group vid
  if_ok "${baseid:="$(str_word $base)"}" &&
  if_ok "${baseids:="$baseid main std"}" || return

  main_handle "$baseids" subcmd_load main_${main}_load || true
  $subcmd_load "$@" || return
  test -z "${subcmd_alias-}" || { shift; set -- $subcmd "$@" ; }
  test ${c:-0} -gt 0 && shift $c ; c=0

  test -n "${subcmd_func-}" || {
    $us_log info "" "No subcommand '$subcmd' after subcmd-load" "$subcmd_load"
    $us_log err "" "No such subcommand found '$subcmd'" "$baseids"
    return 250
  }
  func_exists "${subcmd_func-}" || {
    $us_log crit "" "No such subcommand defined '$subcmd'" "$baseids"
    return 249
  }

  test ${verbosity:-${v:-5}} -gt 5 &&
    $us_log notice "" "Running main subcmd '$scriptname:$subcmd'..."  "$subcmd_func" ||
    $us_log notice "" "Running main subcmd '$scriptname:$subcmd'..."
  $subcmd_func "$@" && r=0 || { r=$?
    $us_log error "" "Main subcommand '$scriptname:$subcmd' failed" "$r"
  }

  main_handle "$baseids" subcmd_unload main_${main}_unload || true
  $subcmd_unload

  return $r
}

daemon()
{
  note "Daemonize at $$"

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
  : "$(str_word "$PWD")"
  eval $1_key="$hnid:${base}-${subcmd}:$_"
}

# Write/Parse simple line protocol from main_bg instance at main_sock
# TODO see bg.lib.sh
main_bg_writeread () # ~ <Cmd ...>
{
  #shellcheck disable=2162
  printf -- "%\r\n" "$*" | socat -d - "UNIX-CONNECT:$main_sock" 2>&1 |
      tr "\r" " " | while read line
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
# XXX: cleanup

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

#  local pwd="$(pwd -P)" ppwd="$PWD" scm= scmdir=
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
