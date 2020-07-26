#!/bin/sh


# Lists and tasks

gtasks_list_arg()
{
    test -z "$1" && list=Standaardlijst || list="$1"
}
gtasks_num_arg()
{
    test -z "$1" && return 1 || num="$1"
}
gtasks_list_opt()
{
  test -z "$1" && {
    list="-l Standaardlijst"
  } || {
    test "${1:0:1}" = "-" && {
      # possibly use verbatim opts (-L)
      list="$1"
    } || {
      list="-l $1"
    }
  }
}
gtasks_opts()
{
  cnt=0
  gtasks_opts=
  while test "${1:0:1}" = "-"
  do
    gtasks_opts="$gtasks_opts $1"
    cnt=$(( $cnt + 1 ))
    shift 1
  done
  return $cnt
}

htd__gtasks_lists()
{
  test -n "$gtasks_opts" || gtasks_opts="-dsc"
  gtasks -ll $gtasks_opts
}

# List tasks in lists
htd__gtasks()
{
  gtasks_opts $@
  shift $?
  test -n "$gtasks_opts" || gtasks_opts="-dsc"
  test -z "$1" && {
    gtasks_list_opt
    gtasks $list $gtasks_opts
  }
  while test $# -gt 0
  do
    gtasks_list_opt $@ && shift 1
    gtasks $list $gtasks_opts
  done
}

# Add task to list with title
htd__new_task()
{
  gtasks_list_arg $1 && shift 1
  gtasks -l "$list" -a - -t "$@"
}

# Edit notes of a task in the $EDITOR
htd__gtask_note()
{
  gtasks_list_arg $1 && shift 1
  gtasks_num_arg $1 && shift 1 || exit 1
  tmpf=/tmp/gtasks-$list-$num-note
  title="$(gtasks -dsc -l "$list" -gt $num)"
  mkdir -p $(dirname $tmpf)
  gtasks -dsc -l "$list" -gn $num > $tmpf.current
  check_pre=$(md5sum $tmpf.current | cut -f 1 -d ' ')
  echo -e "$title\n" > $tmpf.txt
  cat $tmpf.current >> $tmpf.txt
  $EDITOR $tmpf.txt
  new_title=$(head -n 1 $tmpf.txt)
  tail -n +3 $tmpf.txt > $tmpf.new
  check=$(md5sum $tmpf.new | cut -f 1 -d ' ')
  test "$title" != "$new_title" && {
    printf "Updating title ... "
    gtasks -l "$list" -e $num -t "$new_title" -dsl
  } || {
    echo "No changes to title. "
  }
  test "$check_pre" != "$check" && {
    printf "Updating notes ... "
    gtasks -l "$list" -e $num -n "$(cat $tmpf.new)" -dsl
  } || {
    echo "No changes to notes. "
  }
}

# Get or updte title of task
htd__gtask_title()
{
  gtasks_list_arg $1 && shift 1
  gtasks_num_arg $1 && shift 1 || exit 1
  test -z "$1" && {
    gtasks -dsc -l "$list" -gt $num
  } || {
    gtasks -dsc -l "$list" -e $num -t "$1"
  }
}

# Toggle task completed status
htd__done()
{
  test -n "$2" && {
    test "$2" -gt 0 && {
      gtasks_list_arg $1 && shift 1
      gtasks_num_arg $1 && shift 1 || exit 1
    }
  } || {
    test -n "$1" -a "$1" -gt 0 && {
      # default list
      gtasks_list_arg
      gtasks_num_arg $1 && shift 1 || exit 1
    }
  }
  gtasks -dsc -l "$list" -c $num
}

#
