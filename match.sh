#!/bin/sh
match_src=$_

set -e

match_version=0.0.0-dev # script-mpe



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
      && echo $var_match  || noop
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
  #echo grep_pattern=$grep_pattern
  #vars=$MATCH_NAME_VAR_matched
  #echo path=$path grep_pattern=$grep_pattern
  #echo vars=$vars
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
  local scriptname=match base="$(basename "$0" .sh)" verbosity=5 \
    scriptdir="$(cd "$(dirname "$0")"; pwd -P)"

  match_lib || return $(( $? - 1 ))

  case "$base" in $scriptname )

      match_init || return $?

      # Execute
      run_subcmd "$@"
      ;;

  esac
}

match_lib()
{
  test -z "$__load_lib" || return 1
  test -n "$scriptdir"
  export SCRIPTPATH=$scriptdir
  . $scriptdir/util.sh
  util_init
  . $scriptdir/box.init.sh
  box_run_sh_test
  . $scriptdir/main.lib.sh "$@"
  . $scriptdir/main.init.sh
  # -- match box init sentinel --
}

match_init()
{
  local __load_lib=1
  test -n "$scriptdir" || return 13
  . $scriptdir/box.lib.sh "$@"
  . $scriptdir/match.lib.sh "$@"
  . $scriptdir/os.lib.sh
  . $scriptdir/date.lib.sh
  . $scriptdir/doc.lib.sh
  . $scriptdir/table.lib.sh
  # -- match box lib sentinel --
  set --
}

test "$match_src" != "$0" && {
  set -- load-ext
}
case "$1" in "." | "source" )
  match_src=$2
  set -- load-ext
;; esac

# Ignore login shell
case "$0" in "" ) ;; "-"* ) ;; * )

  # Ignore 'load-ext' sub-command
  case "$1" in load-ext ) ;; * )

    match_main "$@" || exit $? ;;

  esac
  ;;

esac
