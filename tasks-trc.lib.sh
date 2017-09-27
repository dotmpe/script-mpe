#!/bin/sh

tasks__trc()
{
  local act=$1; shift;
  test -n "$1" && trc_tags="$@" || {
      htd_tasks_load tags coops
      trc_tags="$todo_slug $tasks_coops $tasks_tags"
    }
  case "$act" in
  show-tags )
    echo $todo_slug
    echo $tasks_coops
    echo $tasks_tags
  ;;
  list )            items=1 tasks__trc_list "$@"
  ;;
  list-num-ids ) test -n "$1" || set -- "$todo_slug"
                 item_ids=1 tasks__trc_list "$@"
  ;;
  list-ref-ids )  ref_ids=1 tasks__trc_list "$@"
  ;;
  list-refs ) items=0 item_ids=0 tasks__trc_list "$@"
  ;;
  next-id )                 tasks__trc_next_id "$@"
  ;;
  list-uids ) test -n "$1" || set -- "$trc_tags"
                     uids=1 tasks__trc_list "$@"
  ;;
  * )
    error "tasks-trc? '$act'" 1
  ;; esac
}

tasks__trc_list()
{
  test -n "$1" || set -- $trc_tags
  note "Trc.list: '$*'"
  # Build the grep/sed patterns from a space separated list of tags
  trueish "$items" && {
    tag_grep="\<\($( echo $@ | sed 's/\ /\\\|/g' )\)\>"
  } || {
    trueish "$uids" && {
      tag_grep="\<\($( echo $@ | sed 's/\ /\\\|/g')\)\>:.*uid:\([0-9a-zA-Z_-][0-9a-zA-Z_-]*\)\($\|\ \).*"
      tag_sed="s/^(.*[[:space:]])?uid:([0-9a-zA-Z_-]*).*$/\\2/"
    } || {
      tag_grep="\<\($( echo $@ | sed 's/\ /\\\|/g' )\)\>[\ :-]\?\([0-9][0-9]*\)"
      trueish "$item_ids" && {
        tag_grep="$tag_grep:"
        tag_sed="s/^(.*[[:punct:][:space:]])?($( echo $@ | sed 's/\ /|/g' ))[\\ :-]?([0-9][0-9]*):.*/\\2\\ \\3/"
      }
      trueish "$ref_ids" && {
        tag_sed="s/^(.*[[:punct:][:space:]])?($( echo $@ | sed 's/\ /|/g' ))[\\ :-]?([0-9][0-9]*).*/\\2\\ \\3/"
      } ||
        tag_sed="s/^(.*[[:punct:][:space:]])?($( echo $@ | sed 's/\ /|/g' ))[\\ :-]?([0-9]*).*/\\2\\ \\3/"
    }
  }
  info "Grep: '$tag_grep'"
  info "Sed: '$tag_sed'"
  info "Hub: '$tasks_hub'"
  info "Slug: '$todo_slug'"
  info "Docs: '$todo_document  $todo_done'"
  # Run grep/sed
  test -n "$tag_sed" && {
    eval "grep -nHsrI '$tag_grep' $tasks_hub $todo_document $todo_done" |
      eval "sed -E '$tag_sed' "
  } || {
    eval "grep -nHsrI '$tag_grep' $tasks_hub $todo_document $todo_done" || return $?
  }
}

tasks__trc_last_id()
{
  test -n "$1" || error last-id 1
  item_ids=1 tasks__trc_list "$@" | sort | tail -n 1 | awk '{print $2;}'
}

tasks__trc_next_id()
{
  test -z "$2" || error next-id 1
  test -n "$1" || set -- $todo_slug
  echo $(( $(tasks__trc_last_id "$@" ) + 1 ))
}

tasks__trc_init()
{
  noop
}

tasks__trc_add()
{
  noop
}

