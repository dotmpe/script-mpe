#!/usr/bin/env bash
#!/bin/sh
match_src=$_

set -e

version=0.0.4-dev # script-mpe



### User commands


match_load()
{
  MATCH_NAME_VARS=
  #MATCH_NAME_VARS="SZ SHA1_CKS MD5_CKS CK_CKS EXT NAMECHAR NAMEPARTS ALPHA ANY PART OPTPART"

  match_load_table vars
  # -- match box load sentinel --
  set --
}


match__var_names()
{
  echo $MATCH_NAME_VARS
}



match__name_pattern_test()
{
  echo MATCH_NAME_VARS=$MATCH_NAME_VARS
  match_name_pattern "$1" "$2"
  #./@NAMEPARTS.@SHA1_CKS.@EXT"
  echo grep_pattern=$grep_pattern
}

match__name_pattern_opts()
{
  req_arg "$1" "match name-pattern-opts" 1 pattern && shift 1 || return 1
  for var_match in $MATCH_NAME_VARS
  do
    echo "$pattern" | grep '@\<'$var_match'\>' > /dev/null \
      && echo $var_match  || true
  done
}


# parse named vars from path using pattern
match__name_vars()
{
  local pattern path
  req_arg "$1" "match name-vars" 1 pattern && shift 1 || return 1
  req_arg "$1" "match name-vars" 1 path && path="$@" || return 1
  local var2 vars
  vars=$(match__name_pattern_opts "$pattern")
  match_name_pattern "$pattern"
  echo "$path" | grep '^'"$grep_pattern"'$' > /dev/null && {
    for var2 in $vars
    do
      match_name_pattern "$pattern" $var2
      echo "$path" | grep '^'$grep_pattern'$' > /dev/null || {
        error "Could not retrieve part $var2"
        continue
      }
      echo grep_pattern=$grep_pattern
      printf "$var2="
      echo "$path" | sed -Po 's/^'$grep_pattern'$/\var/'
    done

  } || {
    error "mismatch '$path'"
    return 1
  }
}

# change glob to regex pattern and match against path
match__glob()
{
  match_grep_pattern_test "$1" || error "build regex failed on '$1'" 2
  glob_pat="$(echo "$p_" | sed 's/\\\*/.*/g')"
  shift 1
  echo "$@" | grep '^'$glob_pat'$' > /dev/null || return 1
}

match__regex()
{
  compile_glob "$1"
}

# check given name with all name patterns
match__names()
{
  local glob_match name_pattern tag
  match_req_names_tab
  cat $tabs | grep -Ev '^(#.*|\s*)$' | while read glob_match name_pattern tag
  do
    for name in "$@"
    do
      # Only match templates when given name matches the templates glob pattern
      match__glob "$glob_match" "$name" && {
        #
        match__name_vars "$name_pattern" "$name" 2> /dev/null > /dev/null && {
          test -z "$tag" && {
            echo "$glob_match $name_pattern $name"
          } || echo "Match for $tag: $glob_match $name_pattern"
        }
      }
    done
    #match_name_pattern "$pattern" ""
  done
}


# Compile new table
# FIXME req_arg_pattern=("Name pattern" pattern)
# FIXME req_arg_pattern_name=("Pattern name" name)
match__compile()
{
  req_arg "$1" "match compile" 1 pattern && shift 1 || return 1
  req_arg "$1" "match compile" 2 pattern_name && shift 1 || return 1
  match_grep_pattern_test "$pattern" || return 1
}

#
req_arg()
{
  label=$(eval echo \${req_arg_$4[0]})
  varname=$(eval echo \${req_arg_$4[1]})
  test -n "$1" || {
    warn "$2 requires argument at $3 '$label'"
    return 1
  }
  test -n "$varname" && {
    export $varname="$1"
  } || {
    export $4="$1"
  }
}



### Main


match_main()
{
  local \
      scriptname=match \
      base="$(basename "$0" ".sh")" \
      verbosity=4 \
    scriptpath="$(cd "$(dirname "$0")"; pwd -P)"

  match_init || return $(( $? - 1 ))

  case "$base" in $scriptname )

      match_load || return $?

      # Execute
      main_run_subcmd "$@"
      ;;

  esac
}

# Initial step to prepare for subcommand
match_init()
{
  local scriptname_old=$scriptname; export scriptname=match-init

  INIT_ENV="init-log strict 0 0-src 0-u_s 0-1-lib-sys ucache scriptpath box" \
    . ${CWD:="$scriptpath"}/tools/main/init.sh || return
  lib_load box os date doc table match main std stdio src-htd
  # -- match box init sentinel --
  export scriptname=$scriptname_old
}


### Subcmd init, deinit

# Pre-exec: post subcmd-boostrap init
match_load()
{
  local scriptname_old=$scriptname; export scriptname=match-load

  INIT_LOG=$LOG lib_init || return
  # -- match box lib sentinel --
  export scriptname=$scriptname_old
}

#test "$match_src" != "$0" && {
#  set -- load-ext
#}
#case "$1" in "." | "source" )
#  match_src=$2
#  set -- load-ext
#;; esac

# Main entry - bootstrap script if requested
# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )

  # Ignore 'load-ext' sub-command
  test "$1" != load-ext || __load_lib=1
  test -n "${__load_lib-}" || {
    match_main "$@" || exit $?
  }
;; esac

# Id: script-mpe/0.0.4-dev match.sh
