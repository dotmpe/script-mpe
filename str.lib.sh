#!/bin/sh


# ID for simple strings without special characters
mkid()
{
	id=$(echo "$1" | tr '[:blank:][:punct:]' '_')
}

# to filter strings to valid id
mkvid()
{
	vid=$(echo "$1" | sed 's/[^A-Za-z0-9_]\{1,\}/_/g')
	# Linux sed 's/\([^a-z0-9_]\|\_\)/_/g'
}
mkcid()
{
	cid=$(echo "$1" | sed 's/\([^a-z0-9-]\|\-\)/-/g')
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


# Set env for str.lib.sh
str_load()
{
    test -n "$ext_sh_sub" && {
        printf "" #info "Existing ext_sh_sub=$ext_sh_sub"
    } || {
        test "$(echo {foo,bar}-{el,baz})" != "{foo,bar}-{el,baz}" \
            && ext_sh_sub=1 \
            || ext_sh_sub=0
        # debug "Initialized ext_sh_sub=$ext_sh_sub"
    }
}


