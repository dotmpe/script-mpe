#!/bin/sh


# TODO: list targets, first explicit then have go/try at implicit stuff, maybe.
# TODO: ignore vars for now, maybe also have a go at that
# But first collect targets, src-file and pre-requisites

# NOTE: vars must not mix with pre-requisites lines; not sure how Make dialects deal
# with that


make_lib_load()
{
  test -n "$ggrep" || ggrep=ggrep
  test -n "$make_op_fd" || make_op_fd=4

  # Special (GNU) Makefile vars
  make_special_v="$(echo MAKEFILE_LIST .DEFAULT_GOAL MAKE_RESTARTS \
    MAKE_TERMOUT MAKE_TERMERR .RECIPEPREFIX .VARIABLES .FEATURES .INCLUDE_DIRS)"

  make_other_builtin_v="$(echo .SHELLFLAGS GNUMAKEFLAGS MAKE MAKELEVEL \
    MAKE_HOST MAKECMDGOALS MAKE_VERSION MAKE_COMMAND MAKEFLAGS MAKEFILES \
    "<D ?F ?D @D @F %F *D ^D %D *F +D +F <F ^F" \
    CURDIR OLDPWD MFLAGS SUFFIXES "-*-eval-flags-*-" )"

  # Special (GNU) Makefile targets
  make_special_t=' .PHONY .SUFFIXES .DEFAULT .PRECIOUS .INTERMEDIATE
.SECONDARY .SECONDEXPANSION .DELETE_ON_ERROR .IGNORE .LOW_RESOLUTION_TIME
.SILENT .EXPORT_ALL_VARIABLES .NOTPARALLEL .ONESHELL .POSIX EOM '

  # Expand to single line of var-names
  make_list_internal_vars='filter-out $(shell env | sed '\''s/=.*//g'\''), $(.VARIABLES)'
  make_list_vars='filter-out $(shell env | sed '\''s/=.*//g'\'') '"$make_special_v"' '"$make_other_builtin_v"', $(.VARIABLES)'

  # Expand to shell recipe echo'ing var name/values
  make_expand_vars='{ $(foreach VAR,%s,echo $(VAR)="$($(VAR))";) }'
}

# Print DB, no action
# NOTE: without targets it seems make will only go so far in building its
# database, so including all makefile dirs by default (assuming they may have
# targets associated; it seems make will then also load the DB with these)
make_dump()
{
  make -p -f "$@"
}

# No builtin rules or vars
make_dump_nobi()
{
  make -Rrp -f "$@"
}

make_nobi()
{
  trueish "$make_question" && {
    make -Rrq -f "$@"
    return $?
  } || {
    make -Rr -f "$@"
    return $?
  }
}


make_nobi_eval() # Expr [Makefile] [Make-args...]
{
  local mkf="$2" expr="$1" ; shift 2
  test -n "$mkf" || mkf="/dev/null"
  make -Rr -f"$mkf" --eval="$expr" "$@"
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
        htd_make_srcfiles
        continue
    }
    test -d "./$method/" && {
        find ./$d -iname '*Rules*.mk' -o -iname 'Makefile'
        continue
    }
  done
}

# Append target with make-eval and call that target, embedding the expression
# from stdin. See make-echo-op var for printf string template. Capture the
# output with fd-4, so stdout,err is ignored, and shell, make and even Bats
# can go about their way (the makefile root may contain macros thats run
#  directly).
make_op() # [make_op_fd=4] ~ [Makefile] [echo|recipe]
{
  test -n "$2" || set -- "$1" "echo"
  local strf="$(eval echo \"\$make_graft_${2}_op\")"
  local outf=$(setup_tmpf .out)
  eval "exec $make_op_fd>$outf"
  debug "make_nobi_eval '\$( printf '$strf >&$make_op_fd' '\$( cat )' ) '$1' htd-make-op"
  make_nobi_eval "$( printf "$strf >&4" "$( cat )" )" "$1" htd-make-op \
        2>&1 \
        1>/dev/null
  cat "$outf"
  rm "$outf"
}

# Default make part to append target which expands make expression to one line
make_graft_echo_op='\nhtd-make-op:: ; @echo "$(%s)"'

# Generic fmt to add target with recipe (shell with make macro)
make_graft_recipe_op='\nhtd-make-op:: ; @%s'


# List variable names, excluding inherited env. But includes all specials and
# other builtins.
htd_make_list_internal_vars() # Makefile
{
  echo "$make_list_internal_vars" | make_op "$1" | tr ' ' '\n'
}

# List variable names, but only those defined by this or included makefiles.
# Excludes inherited shell env, and all special and other builtin vars.
htd_make_list_vars() # Makefile
{
  echo "$make_list_vars" | make_op "$1" | tr ' ' '\n'
}


# "Expand" make variable or macro from given Makefile. See make-op.
htd_make_expand() # Var-Name [Makefile]
{
  test -n "$1" || error "var-name expected" 1
  echo "$1" | make_op "$2"
}


# Instead of a foreach invoking make Nth time, extract the vars in one expression
htd_make_expand_all() # [Makefile] [Vars...]
{
  local mkf="$1" ; shift
  test -n "$1" || set -- "\$($make_list_vars)"
  printf "$make_expand_vars" "$*" | make_op "$mkf" recipe
}


# Show make var declaration (grep from database dump)
htd_make_vardef() # Var [Makefile] [Make-args...]
{
  local varname="$1" mkf="$2" ; shift 2
  make -qpRr -f"$mkf" "$@" |
      grep '^'"$varname"'\ *:\?=\ *' |
      sed 's/^.*\ *[?:+!]*=\ *//'
}


# Print features of local make dist
htd_make_features()
{
  htd_make_expand .FEATURES | tr ' ' '\n'
}

# List all included makefiles, usefull to build dependency list for cache validation
htd_make_srcfiles() # [Makefile]
{
  htd_make_expand MAKEFILE_LIST "$1" | tr ' ' '\n'
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
