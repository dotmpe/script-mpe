#!/bin/sh


# TODO: list targets, first explicit then have go/try at implicit stuff, maybe.
# TODO: ignore vars for now, maybe also have a go at that
# But first collect targets, src-file and pre-requisites

# NOTE: vars must not mix with pre-requisites lines; not sure how Make dialects deal
# with that


make_lib_load()
{
  test -n "$ggrep" || ggrep=ggrep
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
make_dump()
{
  local q=0 ; make -pq -f "$@" ; q=$?
  trueish "$make_question" || return 0
  return $q
}

# No builtin rules or vars
make_dump_nobi()
{
  local q=0 ; make -Rrpq -f "$@" ; q=$?
  trueish "$make_question" || return 0
  return $q
}

# List all local makefiles; the exact method differs a bit per workspace.
# Set method=git,
# To include all GIT tracked, db to include MAKEFILE_LIST from the dump,
# or set directories to search those. Default is $package_ext_make_files,
# or git,db
htd_make_files()
{
  test -n "$package_ext_make_files" || method="git db"
  test -n "$method" || method="$package_ext_make_files"
  info "make-files method: '$method'"
  for method in $method
  do
    # XXX: Makefile may indicate different makefile base! still, including
    # everything but maybe want to get main file and includes only
    test "$method" = "git" && {
        git ls-files | grep -e '.*Rules.*.mk' -e '.*Makefile'
        continue
    }
    test "$method" = "db" && {
        htd_make_expand MAKEFILE_LIST | tr ' ' '\n'
        continue
    }
    test -d "./$method/" && {
        find ./$d -iname '*Rules*.mk' -o -iname 'Makefile'
        continue
    }
  done
}

# Expand variable from database
htd_make_expand()
{
    test -n "$1" || set -- MAKEFILE_LIST
    varname="$1" ; shift
    make -pq "$@" 2>/dev/null |
        grep '^'"$varname"' := ' |
        sed 's/^'"$varname"' := //'
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

# Return all targets/prerequisites given a make data base dump on stdin
make_targets()
{
  esc=$(printf -- '\033')
  grep -v -e '^ *#.*' -e '^\t' -e '^[^:]*\ :\?=\ ' |
  while IFS="$(printf '\n')" read -r line
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
  done | $ggrep -oe '^[^:]*:*'
}

make_targets_()
{
  esc=$(printf -- '\033')
  grep -v \
      -e '^ *#' \
      -e '^[A-Za-z\.,^+*%?<@\/_][A-Za-z0-9\.,^?<@\/_-]* \(:\|\+\|?\)\?=[ 	]' \
      -e '^\(	\| *$\)' \
      -e '^\$(.*)$' \
      -e '^[ 	]*'"$esc"'\[[0-9];[0-9];[0-9]*m' |
  while IFS="$(printf '\n')" read -r line
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

# List all targets (from every makefile dir by default)
htd_make_targets()
{
  test -n "$*" || set -- $(htd_make_files | act=dirname foreach_do | sort -u)
  note "Setting make-targets args to '$*'"
  upper=0 default_env out-fmt list

  # NOTE: need to expand vars/macro's so cannot grep raw source; so need way
  # around to get back at src-file after listing all targets, somewhere else.

  verbosity=0  \
  make_dump "$@" 2>/dev/null | make_targets | {
    case "$out_fmt" in

        json-stream )
  while read -r target prereq
  do
    # double-colon rules are those whose scripts execution differ per prerequisite
    # they execute everytime while no prerequisites targets are given, or only
    # per rule that is out of date. While normal targets can have only one rule.
    # <https://stackoverflow.com/questions/7891097/what-are-double-colon-rules-in-a-makefile-for#25942356>
    fnmatch "*::" "$target" && depends=1 || depends=
    # NOTE: targets are already split in make-dump, ie. no need to split,
    # each json-stream line always has one target name, but multiple may exists
    # even if multiple != True
    target="$(echo "$target" | sed 's/:*$//')"
    echo "$make_special_t" | grep -qF "$target" && special=1 || special=
    test -n "$prereq" &&
        prereq_list="[ \"$( echo $prereq | sed 's/ /", "/g' )\" ]" ||
        prereq_list='[]'
    out="{\"target\":\"$target\","
    trueish "$depends" && out="$out\"multiple\":\"yes\"," ;
    trueish "$special" && out="$out\"special\":\"yes\"," ;
    echo "$out\"prerequisites\":$prereq_list}"
  done
          ;;

        list ) sort -u ;;

        * ) error "Unknown format '$out_fmt'" 1 ;;
    esac
  }
}
