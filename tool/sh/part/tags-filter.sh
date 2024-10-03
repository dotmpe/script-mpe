#!/bin/sh
set -e
# XXX: cleanup
#test -n "$lname"
#  | grep -Ev '\<'"$lname"'\>.\<no[-]?check\>' \
grep -v '\<TODO\>\.\<txt\>' \
  | grep -v '\<TODO\>\.\<list\>' \
  | grep -Ev '\<tasks\>.\<no[-]?check\>' \
  | grep -v '\<tasks\>.\<ignore\>' \
  | while IFS=: read srcname linenr comment
do
  grep -q '\<tasks\>.\<ignore\>.\<file\>' $srcname ||
  # Preserve quotes so cannot use echo/printf w/o escaping. Use raw cat.
  { cat <<EOM
$srcname:$linenr: $comment
EOM
  }
done
# Sync:
# Id: script-mpe/0.0.4-dev tool/sh/part/tags-filter.sh
