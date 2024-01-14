#!/bin/sh

tasks_lib__load ()
{
  test -n "${TASK_EXT-}" || TASK_EXT="ttxtm"
  test -n "${TASK_EXTS-}" || TASK_EXTS=".ttxtm .list .txt"
  test -n "${tasks_hub-}" || {
      # XXX: static init only, move elsewhere or add $PWD
    test ! -e "to" || tasks_hub=to
  }
  : "${tasks_filetypes:=tasks todo todo.txt}"
}

tasks_package_defaults()
{
  test -n "$package_pd_meta_tasks_hub" || {
    test -d to && export package_pd_meta_tasks_hub=to
  }
}

# Return TODO.txt tags (contexts and projects) from file(s) or stdin
tasks_todotxt_tags() # Grep for tags in file
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
    $LOG debug :tasks-hub-tags "Contexts" "=${contexts:-(unset)}"
    trueish "$contexts" && {
      test "$(echo $tasks_hub/do-at-*.*)" = "$tasks_hub/do-at-*.*" &&
        warn "No local task contexts" ||
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


# [tasks_echo] [tasks_modify]
tasks_add_dates_from_scm_or_def() # [date] ~ TODO.TXT [date_def]
{
  trueish "$tasks_echo" && tasks_modify=0 || tasks_modify=1
  vc_getscm && {
    vc_commit_for_line "$1" 1 >/dev/null # Setup cache now
  } || {
    test -n "$2" && date="$2"
    test -n "$date" || error "Nothing to get date from" 1
  }
  local tmpf="$(setup_tmpf .tasks-add-dates)"
  cp "$1" "$tmpf"

  local lnr=0 todotxt= date_def=$date date=
  while read todotxt
  do
    lnr=$(( $lnr + 1 ))
    date="$(echo "$todotxt" | todo_txt_grep_date)"
    { # Unless we have a date or comment line, lookup the commit ISO date
      test -n "$date" || echo "$todotxt" | $ggrep -q '^\s*\(#.*\)\?$'
    } || {
      sha1=$(vc_commit_for_line "$1" "$lnr") || continue
      date="$(vc_author_date "$sha1" | cut -d' ' -f1)"
      test -n "$date" && {
        echo "$todotxt" | todo_txt_set_created "$date"
      } || {
        echo "$todotxt" | todo_txt_set_created "$date_def"
      }
      continue
    }
    echo "$todotxt"
  done <"$tmpf" | {
    trueish "$tasks_modify" && {
      cat >"$1.tmp" || return
      # Dont update during pipeline, wait for cat to complete.
      cat "$1.tmp"> "$1"
      rm "$1.tmp"

    } || cat
  }
  rm "$tmpf"
}

# TODO: track any task file in STTAB or given file
# XXX: should read tab into AST index, and update when needed (see meta.lib)
tasks_scan () # (sttab) ~ <Tasks-file> [<Tasks-tab>]
{
  test -n "${sttab:?}" && {
    $sttab.tab-exists || return
  } || {
    create sttab StatTab "${STTAB:?}" ||
      $LOG error : "Failed to load stattab index" "E$?:$STTAB" $? || return
  }

  #typeset file{version,id,mode}
  out_fmt=${out_fmt:-} tasks_scan_prio "${1:?}" &&
    cnt=$(( cnt + 1 )) ||
    test ${_E_next:?} -eq $? && errs=$(( errs + 1 )) ||
    test ${_E_continue:?} -eq $_ && pass=$(( pass + 1 )) ||
    return $_
}

# XXX: check how many priorities there are in the tasks file and what level
# they are.
# Normally this list files which have any priority
#
tasks_scan_prio () # (out-fmt) ~ <File> [<Threshold>]
{
  filereader_skip "${1:?}" ${tasks_filetypes:?} || return ${_E_next:?}
  typeset update
  # @TodoFile @Context @FileReader
  # @Status => sum @TodoTxt.PRI
  pri_cnt=$(meta_xattr__get "${1:?}" prio-count) ||
  {
    update=true
    pri_="$(task_field_prios "${2-}" < "${1:?}")" &&
    pri_cnt=$(<<< "$pri_" count_lines) || pri_cnt=0
  }
  "${update:-false}" && {
    meta_xattr__set "${1:?}" prio-count "$pri_cnt" || return
  }
  test $pri_cnt -eq 0 && {
    case "${out_fmt:-files}" in
      ( files ) ;;
      ( stats ) echo "0 $1" ;;
      ( summary ) echo "${1:?} priorities: [no data]" ;;
    esac
    return ${_E_continue:?}
  } || {
    case "${out_fmt:-files}" in
      ( files ) echo "$1" ;;
      ( stats ) echo "$pri_cnt $1" ;;
      ( summary ) echo "${1:?} priorities: $pri_cnt" ;;
    esac
  }
}

# Go over entries and update/add new(er) entries in SRC to DEST.
# SRC may have changes, DEST should have clean SCM status.
tasks_sync_from_to() # SRC DEST
{
  # both files unchanged:
  # could check for merge points maybe? Use object sha1 to find which is newer/
  # what changed.

  true
}

task_field_prios () # ~ [<Threshold>]
{
  ttf_pp="\K"
  todotxt_field_prios
}
