#!/usr/bin/env make.sh
# Created: 2015-08-10

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
match__names () # ~ <Names...>
{
  local glob_match name_pattern tag
  match_req_names_tab
  cat $tabs | grep -Ev '^(#.*|\s*)$' | while read -r glob_match name_pattern tag
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

match_als____version=version
match_als___V=version
match_grp__version=ctx-main\ ctx-std

match_als____help=help
match_als___h=help
match_grp__help=ctx-main\ ctx-std


### Main

MAKE-HERE
INIT_ENV="init-log 0 0-src 0-u_s 0-1-lib-sys 0-std ucache scriptpath box"

main-lib
  lib_load box os date doc table match main std stdio src-htd || return

main-load
  INIT_LOG=$LOG lib_init || return

main-epilogue
# Id: script-mpe/0.0.4-dev match.sh
