#!/bin/sh
match_source=$_

set -e

version=0.0.0+20150911-0659 # script.mpe



### User commands


match_man_1_help="Echo a combined usage, command and docs"
match_spc_help="-h|help [<id>]"
match_help()
{
  std_help match $*
}
match_als__h="help"


match_als__V=version
match_man_1_version="Version info"
match_spc_version="-V|version"
match_version()
{
  echo "$(cat $PREFIX/bin/.app-id)/$version"
}


match_name()
{
  echo -n name
}


match_load()
{
	match_load_table vars
}


match_var_names()
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
	#	awk -v RS='[[:space:]]+' '!a[$0]++{printf "%s%s", $0, RT}')
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
			&& echo $var_match  || echo -n
	done
}


# parse named vars from path using pattern
match_name_vars()
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
			echo -n "$var2="
			echo "$path" | sed -Po 's/^'$grep_pattern'$/\var/'
		done
		echo -n
	} || {
		error "mismatch '$path'"
		return 1
	}
}

# change glob to regex pattern and match against path
match_glob()
{
	match_grep_pattern_test "$1" || return 1
	glob_pat=$(echo "$p_" | sed 's/\\\*/.*/g')
	shift 1
	echo "$@" | grep '^'$glob_pat'$' > /dev/null || return 1
}

# check all name patterns
match_names()
{
	local glob_match name_pattern tag
	cat table.names | grep -Ev '^(#.*|\s*)$' | while read glob_match name_pattern tag
	do
		match_glob "$glob_match" "$@" && {
			match_name_vars "$name_pattern" "$@" 2> /dev/null > /dev/null && {
				test -z "$tag" && {
					echo "$glob_match $name_pattern $@"
				} || echo "Match for $tag: $glob_match $name_pattern"
			}
		}
		#match_name_pattern "$pattern" ""
	done
}

# Load part names and patterns
#req_arg_match_book=( "Table name" book )
match_load_table()
{
	local cmd="match load-table"
	req_arg "$1" "$cmd" 1 match_book
	match_load_defs ~/bin/table.$book
	test -s "$(pwd)/table.$book" && {
			test "$(pwd)" != "$(echo ~/bin)" &&
			match_load_defs "$(pwd)/table.$book" || echo -n
		} || error "No local table.$book"
}

# Compile new table 
# FIXME req_arg_pattern=("Name pattern" pattern)
# FIXME req_arg_pattern_name=("Pattern name" name)
match_compile()
{
	req_arg "$1" "match compile" 1 pattern && shift 1 || return 1
	req_arg "$1" "match compile" 2 pattern_name && shift 1 || return 1
	match_grep_pattern_test "$pattern" || return 1
}


### Main


match__main()
{
  local scriptname=match base=$(basename $0 .sh) verbosity=5

  case "$base" in $scriptname )

      local subcmd_def=stat \
        subcmd_pref= subcmd_suf= \
        subcmd_func_pref=${base}_ subcmd_func_suf=

      match_init
      match_lib

      # Execute
      main "$@"
      ;;

  esac
}

match_init()
{
  test -n "$PREFIX" || PREFIX=$HOME
  . $PREFIX/bin/box.init.sh
  . $PREFIX/bin/util.sh
  box_run_sh_test
  . $PREFIX/bin/main.sh "$@"
  . $PREFIX/bin/box.lib.sh "$@"
  # -- match box init sentinel --
}

match_lib()
{
  # -- match box lib sentinel --
  set --
}


match_load()
{
  MATCH_NAME_VARS=
  #MATCH_NAME_VARS="SZ SHA1_CKS MD5_CKS CK_CKS EXT NAMECHAR NAMEPARTS ALPHA ANY PART OPTPART"

  # -- match box load sentinel --
  set --
}

# Use hyphen to ignore source exec in login shell
if [ -n "$0" ] && [ $0 != "-bash" ]; then
  match__main "$@"
fi
