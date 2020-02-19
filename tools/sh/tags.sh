#!/bin/bash

# Scan for emmbedded tags and comments

# Inherit script-shell or init new
test $SHLVL -gt ${lib_lvl:-0} && status=return || {
  lib_lvl=$SHLVL && set -eu -o posix && status=exit
}

scriptname=tools/sh/tags
# npm bash-parser cannot handle expr with nested subshells
#test -n "$scriptpath" || scriptpath="$(dirname_ 3 "$0")"
test -n "$verbose" || verbose=true
test -n "$exit" || exit=true

lname=script-mpe
test -n "$scriptpath" || scriptpath=$(dirname "$(dirname "$(dirname "$0")")")

type lib_load 2> /dev/null 1> /dev/null ||
    util_mode=lib . $scriptpath/tools/sh/init-wrapper.sh

lib_load sys os std str shell log os-htd sys-htd str-htd
INIT_LOG=$LOG lib_init

out=$(setup_tmpf .out)

note "Embedded issues check.. ($(var2tags verbose exit))"

test -n "$Check_All_Files" || Check_All_Files=0
test -n "$Check_All_Tags" || Check_All_Tags=0

test -z "$1" && {
  trueish "$Check_All_Files" && {
    check_files="*"
  } || {
    # Only go over staged changes
    check_files="$(git diff --name-only --cached --diff-filter=ACMR HEAD)"
    test -n "$check_files" && {
      note "Set check-files to GIT modified files.."
    } || {
      note "Cant find modified files, setting to all files"
      check_files="*"
    }
  }
} || {
  check_files="$@"
}


# TODO: compile this regex
trueish "$Check_All_Tags" && {
  test -n "$tasks_grep_expr" || tasks_grep_expr='\<\(SCRIPT-MPE\|TODO\|FIXME\|XXX\)\>' # tasks:no-check
} || {
  test -n "$tasks_grep_expr" || tasks_grep_expr='\<XXX\>' # tasks:no-check
}

# match for tags, ignore lines with tasks.no.check at the end
# TODO: should move exclude params into pd or lst, once handled ok
test -e .git &&
  src_grep="git grep -n" ||
  src_grep="grep -nsrI \
    --exclude-dir 'build' \
    --exclude-dir jjb \
    --exclude-dir 'vendor' \
    --exclude '*.tmpl' \
    --exclude '*.sw[aop]' \
    --exclude '*~' \
    --exclude '*.lock' \
    --exclude '*.html' \
    --exclude 'TODO.list' \
    --exclude '.package.sh' \
    --exclude '.package.json' \
  "

sh-parts print-err

$src_grep \
    $tasks_grep_expr \
    $check_files \
  | sh-parts tags-filter \
  | {
    trueish "$verbose" && { tee $out; } || { cat - > $out; }
  }

cruft=$(count_lines $out)

ret=0
test -n "$max" || max=0
tags="$(var2tags Check_All_Files Check_All_Tags check_files)"
test $max -ge $cruft && {
  test $max -eq 0 \
    && stderr ok "No cruft found ($tags)" \
    || stderr passed "Ignored $cruft cruft counts"
  rm $out
} || {
  warn "Crufty: $cruft counts ($tags)"
  ret=1
}

trueish "$exit" && $status $ret || $status 0

# Sync:
# Id: script-mpe/0.0.4-dev tools/sh/tags.sh
