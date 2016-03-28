#!/bin/sh
match_source=$_

set -e

match_version=0.0.0+20150911-0659 # script.mpe



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


match_load_defs()
{
  MATCH_NAME_VARS="$MATCH_NAME_VARS $(echo $(grep '^match_[A-Z_][A-Z0-9_]*=.*' $1 |
    sed 's/^match_\([^=]*\)=.*$/\1/g'))"
  # read in as array? try to clean dupes? overrides?
  #echo MATCH_NAME_VARS_new=$MATCH_NAME_VARS_new
  #read -ra MATCH_NAME_VARS<<<$(printf '%s\n' "$MATCH_NAME_VARS_new" |
  #  awk -v RS='[[:space:]]+' '!a[$0]++{printf "%s%s", $0, RT}')

  trueish "$silent" || note "Loading $1"
  . $1
}

# To escape filenames and perhaps other values for use as grep literals
match_grep_pattern_test()
{
  p_="$(echo "$1" | sed -E 's/([^A-Za-z0-9{}(),!@+_])/\\\1/g')"
  # test regex
  echo "$1" | grep "^$p_$" >> /dev/null || {
    error "cannot build regex for $1: $p_"
    echo "$p" > invalid.paths
    return 1
  }
}

# sed/grep tricks to get name parts, find mismatches, matches,
# parse metadata or reformat paths, etc
match_name_pattern()
{
  local pat var
  match_grep_pattern_test "$1" || return 1
  grep_pattern="$p_"
  MATCH_NAME_VAR_matched=
  for var in $MATCH_NAME_VARS
  do
    pat="$(eval echo "\$match_$var")"
    echo "$@" | grep '@'$var > /dev/null && {
      MATCH_NAME_VAR_matched="$(echo $MATCH_NAME_VAR_matched $var)"
    } || {
      continue
    }
    test -n "$2" -a "$2" = "$var" && {
      grep_pattern="$(echo "$grep_pattern" |
        sed 's/@'$var'/\('"$pat"'\)/g' |
        sed 's/\([^\\]\)\([{}()?|]\)/\1\\\2/g' |
        sed 's/\([^\\]\)\([{}()?|]\)/\1\\\2/g'
      )"
    } || {
      #echo "pat=$pat"
      grep_pattern="$(echo "$grep_pattern" |
        sed 's/@'$var'/'"$pat"'/g' |
        sed 's/\([^\\]\)\([{}()?.|]\)/\1\\\2/g' |
        sed 's/\([^\\]\)\([{}()?.|]\)/\1\\\2/g'
      )"
    }
    #echo "grep_pattern='$grep_pattern'"
  done
}

match_name_pattern_test()
{
  echo MATCH_NAME_VARS=$MATCH_NAME_VARS
  match_name_pattern "$1" "$2"
  #./@NAMEPARTS.@SHA1_CKS.@EXT"
  echo grep_pattern=$grep_pattern
}

match_name_pattern_opts()
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
  vars=$(match_name_pattern_opts "$pattern")
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
  local scriptname=match base="$(basename "$0" .sh)" verbosity=5

  case "$base" in $scriptname )

      match_lib || return $(( $? - 1 ))

      local match_default=

      match_init || return $?

      # Execute
      run_subcmd "$@"
      ;;

  esac
}

match_lib()
{
  test -z "$__load_lib" || return 1
  test -n "$LIB" || { test -n "$PREFIX" && { LIB=$PREFIX/lib; } || { LIB=.; } }
  . $LIB/util.sh
  . $LIB/box.init.sh
  box_run_sh_test
  . $LIB/main.sh "$@"
  . $LIB/main.init.sh
  . $LIB/box.lib.sh "$@"
  # -- match box init sentinel --
}

match_init()
{
  local __load_lib=1
  test -n "$LIB" || return 13
  . $LIB/match.lib.sh "$@"
  # -- match box lib sentinel --
  set --
}

# Ignore login shell
case "$0" in "" ) ;; "-"* ) ;; * )

  # Ignore 'load-ext' sub-command
  case "$1" in load-ext ) ;; * )

    match_main "$@" || exit $? ;;

  esac
  ;;

esac
