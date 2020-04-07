#!/usr/bin/env bash

journal_index()
{
  local path base bn entry mtime
  {
    find cabinet/ -type f -iname 'journal.rst' | cut -c9-
    find personal/journal -type f -iname '[0-9][0-9]*[0-9].rst' | cut -c18-
  } | while read path
  do
    for base in $@
    do
      test -e "$base/$path" || continue
      bn="$(basename "$path" .rst)"
      case "$bn" in
        [0-9][0-9][0-9][0-9] | [0-9][0-9][0-9][0-9]-*[0-9][0-9]* )
            entry=$bn
          ;;
        * )
            entry=$(echo "$path" | cut -d'/' -f1-3 | tr ' ' '-' )
          ;;
      esac

      mtime=$(stat -c '%Y' "$base/$path")
      echo "$mtime $entry $path $base"
      break
    done
    test -e "$base/$path" || {
      echo "journal-index: Could not find base for $path in '$*'" >&2
      return 1
    }
  done | sort
}

#
