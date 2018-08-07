#!/bin/sh


# TODO: list targets, first explicit then have go/try at implicit stuff, maybe.
# TODO: ignore vars for now, maybe also have a go at that
# But first collect targets, src-file and pre-requisites

# NOTE: vars must not mix with pre-requisites lines; not sure how Make dialects deal
# with that


make_lib_load()
{
  # Special (GNU) Makefile vars
  make_special_v="$(cat <<EOM
MAKEFILE_LIST
.DEFAULT_GOAL
MAKE_RESTARTS
MAKE_TERMOUT
MAKE_TERMERR
.RECIPEPREFIX
.VARIABLES
.FEATURES
.INCLUDE_DIRS
EOM
)"
  # Special (GNU) Makefile targets
  make_special_t="$(cat <<EOM
.PHONY
.SUFFIXES
.DEFAULT
.PRECIOUS
.INTERMEDIATE
.SECONDARY
.SECONDEXPANSION
.DELETE_ON_ERROR
.IGNORE
.LOW_RESOLUTION_TIME
.SILENT
.EXPORT_ALL_VARIABLES
.NOTPARALLEL
.ONESHELL
.POSIX
EOM
)"
}

# Print DB, no action
# NOTE: without targets it seems make will only go so far in building its
# database, so including all makefile dirs by default (assuming they may have
# targets associated; it seems make will then also load the DB with these)
htd_make_dump()
{
    local q=0 ; make -pq "$@" ; q=$?
    trueish "$make_question" || return 0
    return $q
}

# List all local makefiles
htd_make_files()
{
    git ls-files | grep -e '.*Rules.*.mk' -e '.*Makefile'
}

# Expand variable from database
htd_make_expand()
{
    test -n "$1" || set -- MAKEFILE_LIST
    varname="$1" ; shift
    make -pq "$@" 2>/dev/null |
        grep '^'"$varname"' := ' |
        sed 's/^'"$varname"' := //' |
        tr ' ' '\n'
}

htd_make_expandall()
{
  show_key()
  {
    test -n "$1" || return
    echo $1: $(htd_make_expand "$1")
  }
  act=show_key foreach_do "$make_special_v"
}

# List all included makefiles
htd_make_srcfiles()
{
  htd_make_expand MAKEFILE_LIST
}

# List all targets (from every makefile dir by default)
htd_make_targets()
{
    test -n "$*" || set -- $(htd_make_files | act=dirname foreach_do | sort -u)
    note "Setting make-targets args to '$*'"

    # NOTE: need to expand vars/macro's so cannot grep raw source; so need way
    # around to get back at src-file after listing all targets, somewhere else.

    verbosity=0  \
    htd_make_dump "$@" 2>/dev/null | grep -v \
        -e '^ *#' \
        -e '^[A-Za-z\.,^+*%?<@\/_][A-Za-z0-9\.,^?<@\/_-]* \(:\|\+\|?\)\?=[ 	]' \
        -e '^\(	\| *$\)' \
        -e '^\$(.*)$' \
    | while IFS="$(printf '\n')" read -r line
    do
      case "$line" in
        "include "* )
            continue
          ;;
        "define "* )
            while read -r directive_end
            do test "$directive_end" = "endef" || continue
                break
            done
            continue
          ;;
      esac
      echo "$line"
    done | sed \
        -e 's/\/\.\//\//g' \
        -e 's/\/\/\/*/\//g'
}
