#!/bin/sh

# stdio.lib.sh: additional io for shell scripts


stdio_load()
{
  return 0
}


# setup-io-paths: helper names all temp. IO files (setup_tmpf)
# args: PREFIX
setup_io_paths()
{
  test -n "$1" || error "Unique prefix for proc expected" 1
  fnmatch "*/*" "$1" && error "Illegal chars" 12
  for io_name in $(try_value inputs) $(try_value outputs)
  do
    tmpname=$(setup_tmpf .$io_name $1)
    touch $tmpname
    eval $io_name=$tmpname
    unset tmpname io_name
  done
}


open_io_descrs()
{
  test -n "$fd_num" || fd_num=2
  test -n "$io_dev_path" || io_dev_path=$(io_dev_path)
  for fd_name in $(try_value outputs) $(try_value inputs)
  do
    fd_num=$(( $fd_num + 1 ))
    test $fd_num -lt 10 || error "Maximum number of IO descriptors reached" 1
    # TODO: only one descriptor set per proc, incl. subshell. So useless?
    test -e "$io_dev_path/$fd_num" || {
      debug "exec $(eval echo $fd_num\\\>$(eval echo \$$fd_name))"
      eval exec $fd_num\>$(eval echo \$$fd_name)
    }
  done
}

close_io_descrs()
{
  test -n "$fd_num" || fd_num=2
  for fd_name in $(try_value outputs) $(try_value inputs)
  do
    fd_num=$(( $fd_num + 1 ))
    eval exec $fd_num\<\&-
  done
}

# clean-failed - Deprecated.
# Given $failed pointing to a path, cleanup after a run, observing
# any notices and returning 1 for failures.
clean_failed()
{
  test -z "$failed" -o ! -e "$failed" && return || {
    test -n "$1" || set -- "Failed: "
    test -s "$failed" && {
      count="$(sort -u $failed | wc -l | awk '{print $1}')"
      test "$count" -gt 2 && {
        warn "$1 $(echo $(sort -u $failed | head -n 3 )) and $(( $count - 3 )) more"
        rotate-file $failed .failed
      } || {
        warn "$1 $(echo $(sort -u $failed))"
      }
    }
    test ! -e "$failed" || rm $failed
    unset failed
    return 1
  }
}

# Extra helper to remove empty failed since not all subcmds have same semantics
# New pd load=y accepts empty files. Older subcmds use presence of failed to
# indicate failure. XXX: maybe make old commands echo a line eventually.
rm_failed()
{
  local ret=0

  return $ret
}


# remove named paths from env context; set status vars for line-count and
# truncated contents; XXX: deprecates clean_failed
clean_io_lists()
{
  local count= path=
  while test -n "$1"
  do
    count=0 path="$(eval echo \$$1)"
    test -s "$path" && {
      count="$(count_lines $path)"
      test $count -gt 2 && {
        eval ${1}_abbrev="'$(echo $(sort -u $path | head -n 3 )) and $(( $count - 3 )) more'"
        #rotate-file $failed .failed
      } || {
        eval ${1}_abbrev="'$(echo $(sort -u $path | lines_to_words ))'"
        #rm $1
      }
    }
    test ! -e $path || rm $path
    eval ${1}_count="$count"
    export ${1}_count ${1}_abbrev
    shift
  done
}


# Echo Helpers

passed()
{
  test -n "$1" && {
    test -z "$2" || error "passed '$2': surplus args" 1
    echo "$1" >&3
    stderr ok "$1"
  } || {
    cat >&3
  }
}
skipped()
{
  test -n "$1" && {
    test -z "$2" || error "skipped '$2': surplus args" 1
    echo "$1" >&4
    stderr skip "$1"
  } ||  {
    cat >&4
  }
}
errored()
{
  test -n "$1" && {
    test -z "$2" || error "errored '$2': surplus args" 1
    echo "$1" >&5
    stderr error "$1"
  } || {
    cat >&5
  }
}
failed()
{
  test -n "$1" && {
    test -z "$2" || error "failed '$2': surplus args" 1
    echo "$1" >&6
    stderr fail "$1"
  } || {
    cat >&6
  }
}


# IO reporting helpers

# 0 is no error, other integers are ordered descending;
# 1 is the "highest". semantics may vary? See pd-sketch.rst

# TODO: 4 rules and 7 directives in std-io-report (pd/lst/...)
# passed > 0 :
#    msg passed-count + first targets
# skipped > 0 :
#    msg skipped-count + first targets
#    adjust ret=0 || ret>4 : ret = 4
# failed > 0 :
#    msg failed-count + first targets
#    adjust ret=0 || ret>3 : ret = 3
# errored > 0 :
#    msg errored-count + first targets
#    adjust ret=0 || ret>2 : ret = 2

std_passed_rule()
{
  test $passed_count -gt 0 \
    && info "Passed ($passed_count): $passed_abbrev"
}

std_skipped_rule()
{
  test $skipped_count -gt 0 \
    && {
      note "Skipped ($skipped_count): $skipped_abbrev"
      test $std_io_report_result -eq 0 -o $std_io_report_result -gt 4 \
        && std_io_report_result=4
    }
}

std_failed_rule()
{
  test $failed_count -gt 0 \
    && {
      warn "Failed ($failed_count): $failed_abbrev"
      test $std_io_report_result -eq 0 -o $std_io_report_result -gt 3 \
        && std_io_report_result=3
    }
}

std_errored_rule()
{
  test $errored_count -gt 0 \
    && {
      error "Errors ($errored_count): $errored_abbrev"
      test $std_io_report_result -eq 0 -o $std_io_report_result -gt 2 \
        && std_io_report_result=2
    }
}


std_io_report()
{
  local std_io_report_result=0
  for io_name in $@
  do
    std_${io_name}_rule
  done
  return $std_io_report_result
}


