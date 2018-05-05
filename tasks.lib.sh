#!/bin/sh

tasks_lib_load()
{
  lib_load os str std list
}

htd_migrate_tasks()
{
  info "Migrating tags: '$tags'"
  echo "$tags" | words_to_lines | while read tag
  do
    test -n "$tag" || continue
    case "$tag" in

      +* | @* )
          buffer=$(htd__tasks_buffers $tag | head -n 1 )
          fileisext "$buffer" $TASK_EXTS || continue
          test -s "$buffer" || continue
          note "Migrating prj/ctx: $tag"
          htd_move_and_retag_lines "$buffer" "$1" "$tag"
        ;;

      * ) error "? '$?'"
        ;;
      # XXX: cleanup
      @be.src )
          # NOTE: src-backend needs to keep tag-id before migrating. See #2
          #SEI_TAGS=
          #grep -F $tag $SEI_TAG
          noop
        ;;
      @be.* )
          #note "Checking: $tag"
          #htd__tasks_buffers $tag
          noop
        ;;
    esac
  done
}

htd_remigrate_tasks()
{
  test -n "$1"  || error todo-document 1
  note "Remigrating tags: '$tags'"
  echo "$tags" | words_to_lines | while read tag ; do
    test -n "$tag" || continue
    case "$tag" in

      +* | @* )
          buffer=$(htd__tasks_buffers "$tag" | head -n 1)
          fileisext "$buffer" $TASK_EXTS || continue
          note "Remigrating prj/ctx: $tag"
          htd_move_tagged_and_untag_lines "$1" "$buffer" "$tag"
        ;;

      * ) error "? '$?'"
        ;;

      # XXX: cleanup
      @be.* )
          #note "Committing: $tag"
          #htd__tasks_buffers $tag
          true
        ;;

    esac
  done
}
