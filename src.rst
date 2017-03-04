Source code manipulation

file-insert-at ( FILE:LINE | ( FILE LINE ) ) CONTENT
  Insert line at position using Ed.

file-replace-at ( FILE:LINE | ( FILE LINE ) ) INSERT
  Replace entire line at position using Sed.

file-where-before# 1:where-grep 2:file-path
  ..
file-insert-where-before 1:where-grep 2:file-path 3:content
  ..

truncate-trailing-lines FILE LINES
  Remove leading lines, so that total lines matches LINES

func-comment
  Find function, and if preceeded by comment, return its text.

header-comment FILE
  Use `read-file-lines-while` to match all comment lines, and abort on the last
  recording its line number. Echos entire comment header.

backup-header-comment FILE SUF=.header
  Use `header-comment` and Write header-comment to FILE.

