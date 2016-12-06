#!/bin/sh


# ID for simple strings without special characters
mkid()
{
  test -n "$1" || error "mkid argument expected" 1
  id=$(printf -- "$1" | tr -sc 'A-Za-z0-9\/:_-' '-' )
}

# to filter strings to valid id
mkvid()
{
  test -n "$1" || error "mkvid argument expected" 1
	vid=$(printf -- "$1" | sed 's/[^A-Za-z0-9_]\{1,\}/_/g')
	# Linux sed 's/\([^a-z0-9_]\|\_\)/_/g'
}
mkcid()
{
  test -n "$1" || error "mkcid argument expected" 1
  cid=$(printf -- "$1" | tr 'A-Z' 'a-z' | tr -sc 'a-z0-9' '-')
  #  cid=$(echo "$1" | tr 'A-Z' 'a-z' | sed 's/[^a-z0-9-]/-/g')
}

str_upper()
{
  test -n "$1" \
    && { echo "$1" | tr 'a-z' 'A-Z'; } \
    || { cat - | tr 'a-z' 'A-Z'; }
}

str_lower()
{
  test -n "$1" \
    && { echo "$1" | tr 'A-Z' 'a-z'; } \
    || { cat - | tr 'A-Z' 'a-z'; }
}

str_match()
{
	expr "$1" : "$2" >/dev/null 2>&1 || return 1
}

str_contains()
{
	test -n "$uname" || exit 214
	case "$uname" in
        "" )
            err "No uname set" 1
            ;;
		Linux )
			test 0 -lt $(expr index "$1" "/") || return 1
			;;
		Darwin )
			err "TODO" 1
			echo expr "$1" : "$2"
			expr "$1" : "$2"
			;;
	esac
}

str_replace_start()
{
    test -n "$1" || err "replace-subject" 1
    test -n "$2" || err "replace-find" 2
    test -n "$3" || err "replace-replace" 2
    test -n "$ext_sh_sub" || err "ext-sh-sub not set" 1

    test "$ext_sh_sub" -eq 1 && {
        echo "${1##$2/$3}"
    } || {
        match_grep_pattern_test "$2"
        local find=$p_
        match_grep_pattern_test "$3"
        echo "$1" | sed "s/^$find/$p_/g"
    }
}
str_replace_back()
{
    test -n "$1" || err "replace-subject" 1
    test -n "$2" || err "replace-find" 2
    test -n "$3" || err "replace-replace" 2
    test -n "$ext_sh_sub" || err "ext-sh-sub not set" 1

    test "$ext_sh_sub" -eq 1 && {
        echo "${1%%$2/$3}"
    } || {
        match_grep_pattern_test "$2"
        local find=$p_
        match_grep_pattern_test "$3"
        echo "$1" | sed "s/$find$/$p_/g"
    }
}

str_replace()
{
    test -n "$1" || err "replace-subject" 1
    test -n "$2" || err "replace-find" 2
    test -n "$3" || err "replace-replace" 2
    test -n "$ext_sh_sub" || err "ext-sh-sub not set" 1

    test "$ext_sh_sub" -eq 1 && {
        echo "${1/$2/$3}"
    } || {
        match_grep_pattern_test "$2"
        local find=$p_
        match_grep_pattern_test "$3"
        echo "$1" | sed "s/$find/$p_/g"
    }
}

# x-platform regex match since Bash/BSD test wont chooche on older osx
x_re()
{
  echo $1 | grep -E "^$2$" > /dev/null && return 0 || return 1
}

fnmatch()
{
  case "$2" in $1 ) return 0 ;; *) return 1 ;; esac
}

words_to_lines()
{
  test -n "$1" && {
    while test -n "$1"
    do echo "$1"; shift; done
  } || {
    tr ' ' '\n'
  }
}
lines_to_words()
{
  test -n "$1" && {
    { while test -n "$1"
      do cat "$1"; shift; done
    } | tr '\n' ' '
  } || {
    tr '\n' ' '
  }
}
words_to_unique_lines()
{
  words_to_lines | sort -u
}
unique_words()
{
  words_to_unique_lines | lines_to_words
}
reverse_lines()
{
  sed '1!G;h;$!d'
}

expr_substr()
{
    test -n "$expr" || error "expr init req" 1
    case "$expr" in
        sh-substr )
            expr substr "$1" "$2" "$3" ;;
        bash-substr )
            bash -c 'MYVAR=_"'"$1"'"; printf -- "${MYVAR:'$2':'$3'}"' ;;
        * ) error "unable to substr $expr" 1
    esac
}


# Set env for str.lib.sh
str_load()
{

  test -n "$ext_groupglob" || {
    test "$(echo {foo,bar}-{el,baz})" != "{foo,bar}-{el,baz}" \
          && ext_groupglob=1 \
          || ext_groupglob=0
    # FIXME: part of [vc.bash:ps1] so need to fix/disable verbosity
    #debug "Initialized ext_groupglob=$ext_groupglob"
  }

  test -n "$ext_sh_sub" || ext_sh_sub=0

  #      echo "${1/$2/$3}" ... =
  #        && ext_sh_sub=1 \
  #        || ext_sh_sub=0
  #  #debug "Initialized ext_sh_sub=$ext_sh_sub"
  #}
}

# Try to turn given variable names into a more "terse", human readble string seq
var2tags()
{
  echo $(for varname in $@
  do
    local value="$(eval echo "\$$varname")" \
      pretty_var=$(echo $varname | tr '_' '-')
    test -n "$value" || continue
    falseish "$value" && {
      printf "!$pretty_var "
    } || {
      trueish "$value" && {
        printf "$pretty_var "
      } || {
        printf "$pretty_var=\"$value\" "
      }
    }
  done)
}

properties2sh()
{
  awk 'BEGIN { FS = "=" } ;
      { if (NF<2) next;
      gsub(/[^a-z0-9]/,"_",$1) ;
      print $1"="$2 }' $1
}
