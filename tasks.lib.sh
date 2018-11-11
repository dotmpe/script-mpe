#!/bin/sh

tasks_lib_load()
{
  lib_load os str std list
  test -n "$TASK_EXT" || TASK_EXT="ttxtm"
  test -n "$TASK_EXTS" || TASK_EXTS=".ttxtm .list .txt"
  test -n "$tasks_hub" || {
    test ! -e "to" || tasks_hub=to
  }
}

tasks_package_defaults()
{
  test -n "$package_pd_meta_tasks_hub" || {
    test -d to && export package_pd_meta_tasks_hub=to
  }
}

# Return TODO.txt tags (contexts and projects) from file(s) or stdin
tasks_todotxt_tags()
{
  test -n "$*" || set -- -

  # fix grep output so <file>:<match> always has ': '
  $ggrep -ho '\(^\|\s\)[+@][A-Za-z0-9_][^\ ]*' "$@" |
      sed 's/:\([@+]\)/: \1/' |
      join_lines
}

tasks_hub_tags()
{
  local c=$(( ${#tasks_hub} + 5 ))
  test -z "$1" && {
    trueish "$contexts" && {
      test "$(echo $tasks_hub/do-at-*.*)" = "$tasks_hub/do-at-*.*" &&
        warn "No contexts" ||
      for task_list in $tasks_hub/do-at-*.*
      do
        echo "@$(basenames "$TASK_EXTS .sh" "$task_list" | cut -c${c}-)"
      done
    }
    trueish "$projects" && {
      test "$(echo $tasks_hub/do-in-*.list)" = "$tasks_hub/do-in-*.list" &&
        warn "No projects" ||
      for task_list in $tasks_hub/do-in-*.list
      do
        #echo "+$(basenames "$TASK_EXTS .sh" "$task_list" | cut -c${c}-)"
        echo "+$(basename "$task_list" .list | cut -c${c}-)"
      done
    }
  } || {
    while test $# -gt 0
    do
      fnmatch "*-at-*" "$1" && {
        echo "@$(basenames "$TASK_EXTS" "$1" | cut -c7-)"
      } || {
        fnmatch "*-in-*" "$1" && {
          echo "+$(basenames "$TASK_EXTS" "$1" | cut -c7-)"
        } || {
          echo "@to$(basenames "$TASK_EXTS" "$1" )"
        }
      }
      #echo "<$( htd prefix name "$1" )>"
      shift
    done
  }
}


todo_clean_descr()
{
  echo "$@" | \

  tag_grep_1='^.*(TODO|XXX|FIXME)[\ \:]*(.*)((\?\ )|(\.\ )|(\.\s*$)).*$' # tasks:no-check
  tag_grep_2='s/^.*(TODO|XXX|FIXME)[\ \:]*(.*)((\?\ )|(\.\ )|(\.\s*$)).*$/\1 \2\3/' # tasks:no-check
  tag_grep_3='s/^.*(TODO|XXX|FIXME)[\ \:]*(.*)$/\1 \2/' # tasks:no-check

  grep -E "$tag_grep_1" > /dev/null && {
    clean=$( echo "$@" | sed -E "$tag_grep_2" )
  } || {
    clean=$( echo "$@" | sed -E "$tag_grep_3" )
  }
  tag=$(echo $clean|cut -f 1 -d ' ')
  descr="$(echo ${clean:$(( ${#tag} + 1 ))})"
  test -n "$descr" -a "$descr" != " " && {
    echo $descr | grep -E '(\.|\?)$' > /dev/null || {
      set --
      # TODO: scan lines for end...
    }
  }
}

todo_read_line()
{
  line="$1"
  fn=$(echo $line | cut -f 1 -d ':')
  ln=$(echo $line | cut -f 2 -d ':')
  test "$ln" -eq "$ln" 2> /dev/null \
    || error "Please include line-numbers in the TODO.list" 1
  comment=${line:$((  ${#fn} + ${#ln} + 2  ))}
}
