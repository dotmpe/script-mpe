#!/bin/sh

set -e


# 1:file-name[:line-number] 2:content
file_insert_at()
{
  test -x "$(which ed)" || error "'ed' required" 1

  test -n "$*" || error "arguments required" 1

  local file_name= line_number=
  fnmatch *:[0-9]* "$1" && {
    file_name=$(echo $1 | cut -f 1 -d :)
    line_number=$(echo $1 | cut -f 2 -d :)
    shift 1
  } || {
    file_name=$1; shift 1
    line_number=$1; shift 1
  }

  test -e "$file_name" || error "no file $file_name" 1
  test -n "$1" || error "content expected" 1
  test -n "$*" || error "nothing to insert" 1

  # use ed-script to insert second file into first at line
  note "Inserting at $file_name:$line_number"
  echo "${line_number}a
$1
.
w" | ed $file_name $tmpf
}

file_replace_at()
{
  test -n "$*" || error "arguments required" 1

  local file_name= line_number=

  fnmatch *:[0-9]* "$1" && {
    file_name=$(echo $1 | cut -f 1 -d :)
    line_number=$(echo $1 | cut -f 2 -d :)
    shift 1
  } || {
    file_name=$1; shift 1
    line_number=$1; shift 1
  }

  test -e "$file_name" || error "no file $file_name" 1
  test -n "$line_number" || error "no line_number" 1
  test -n "$1" || error "nothing to insert" 1

  sed $line_number's/.*/'$1'/' $file_name
}

#
# 1:where-grep 2:file-path
file_where_before()
{
  test -n "$1" || error "where-grep required" 1
  test -n "$2" || error "file-path required" 1
  where_line=$(grep -n "$@")
  line_number=$(( $(echo "$where_line" | sed 's/^\([0-9]*\):\(.*\)$/\1/') - 1 ))
}

# 1:where-grep 2:file-path 3:content
file_insert_where_before()
{
  local where_line= line_number=
  test -e "$2" || error "no file $2" 1
  test -n "$3" || error "contents required" 1
  file_where_before "$1" "$2"
  test -n "$where_line" || {
    error "missing or invalid file-insert sentinel for where-grep:$1 (in $2)" 1
  }
  file_insert_at $2:$line_number "$3"
}

truncate_trailing_lines()
{
  test -n "$1" || error "FILE expected" 1
  test -n "$2" || error "LINES expected" 1
  test $2 -gt 0 || error "LINES > 0 expected" 1
  local lines=$(line_count "$1")
  cp $1 $1.tmp
  tail -n $2 $1.tmp
  head -n +$(( $lines - $2 )) $1.tmp > $1
  rm $1.tmp
}

# find '<func>()' line and see if its preceeded by a comment. Return comment text.
func_comment()
{
  test -n "$1" || error "function name expected" 1
  test -n "$2" -a -e "$2" || error "file expected: '$2'" 1
  test -z "$3" || error "surplus arguments: '$3'" 1
  # find function line number, or return 0
  grep_line="$(grep -n "^$1()" "$2" | cut -d ':' -f 1)"
  case "$grep_line" in [0-9]* ) ;; * ) return 0;; esac
  lines=$(echo "$grep_line" | count_words)
  test $lines -gt 1 && {
    error "Multiple lines for function '$1'"
    return 1
  }
  # get line before function line
  func_leading_line="$(head -n +$(( $grep_line - 1 )) "$2" | tail -n 1)"
  # return if exact line is a comment
  echo "$func_leading_line" | grep -q '^\s*#\ ' && {
    echo "$func_leading_line" | sed 's/^\s*#\ //'
  } || noop
}

header_comment()
{
  read_file_lines_while "$1" 'echo "$line" | grep -qE "^\s*#.*$"' || return $?
  export last_comment_line=$line_number
}

# Echo exact contents of the #-commented file header, or return 1
# backup-header-comment file [suffix-or-abs-path]
backup_header_comment()
{
  test -n "$2" || set -- "$1" ".header"
  fnmatch "/*" "$2" \
    && backup_file="$2" \
    || backup_file="$1$2"
  # find last line of header, add output to backup
  header_comment "$1" > "$backup_file" || return $?
}

