#!/bin/sh

set -e


# Insert into file using `ed`. Accepts literal content as argument.
# file-insert-at 1:file-name[:line-number] 2:content
# file-insert-at 1:file-name 2:line-number 3:content
file_insert_at_spc=" ( FILE:LINE | ( FILE LINE ) ) INSERT "
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

  # Note: this loses trailing blank lines
  # XXX: should not have ed period command in text?
  # use ed-script to insert second file into first at line
  stderr info "Inserting at $file_name:$line_number"
  echo "${line_number}a
$1
.
w" | ed -s $file_name
}


# Replace entire line using Sed.
file_replace_at() # ( FILE:LINE | ( FILE LINE ) ) INSERT
{
  test -n "$*" || error "arguments required" 1
  test -z "$4" || error "too many arguments" 1

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


# Quietly get the first grep match' into where-line and parse out line number
file_where_grep() # 1:where-grep 2:file-path
{
  test -n "$1" || error "where-grep arg required" 1
  test -e "$2" -o "$2" = "-" || error "file-path or input arg required" 1
  where_line="$(grep -n "$@" | head -n 1)"
  line_number=$(echo "$where_line" | sed 's/^\([0-9]*\):\(.*\)$/\1/')
}


# Like file-where-grep but grep starting at and after start-line if given.
file_where_grep_tail() # 1:where-grep 2:file-path [3:start-line]
{
  test -n "$1" || error "where-grep arg required" 1
  test -e "$2" || error "file expected '$1'" 1
  test -n "$3" && {
    # Grep starting at line offset
    test -e "$2" || error "Cannot buffer on pipe" 1
    where_line=$(tail -n +$3 "$2" | grep -n "$1" | head -n 1 )
    line_number=$(echo "$where_line" | sed 's/^\([0-9]*\):\(.*\)$/\1/')
  } || {
    file_where_grep "$1" "$2"
  }
}


# Start at Line, verbosely output that line and all before matching Grep.
# Stops at non-matching line, returns 0. first-line == 3:Line for not match
grep_to_first() # 1:Grep 2:File-Path 3:Line
{
  while true
  do
    tail -n +$3 "$2" | head -n 1 | grep -q "$1" || break
    set -- "$1" "$2" "$(( $3 - 1 ))"
  done
  first_line=$3
}


# Like grep-to-last but go backward matching for Grep.
grep_to_last() # 1:Grep 2:File-Path 3:Line
{
  while true
  do
    tail -n +$3 "$2" | head -n 1 | grep -q "$1" || break
    set -- "$1" "$2" "$(( $3 + 1 ))"
  done
  first_line=$3
}


# Like file-where-grep but set line-numer -= 1
file_where_before()
{
  file_where_grep "$@"
  line_number=$(( $line_number - 1 ))
}


file_insert_where_before() # 1:where-grep 2:file-path 3:content
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


# Split file at line in two base on match, discard matched line
split_file_where_grep() # Grep [file-or-stdin]
{
  local line_number= tmpf=
  test -e "$2" || {
    test "$2" = "-" || error "file-path or input arg required" 1
    tmpf="$(setup_tmpf .split-file-where-grep-$(uuidgen))"
    cat - > $tmpf
    set -- "$1" "$tmpf" "$3" "$4"
  }
  test -e "$2" || error "expected $2" 2
  file_where_grep "$1" "$2"
  test -n "$line_number" && {
    head -n +$(( $line_number - 2 )) "$2" >$3
    tail -n +$(( $line_number + 1 )) "$2" >$4
    rm "$2"
  } || {
    cat "$2" > "$3"
    rm "$2"
    return 1
  }
  test -z "$tmpf" -o ! -e "$tmpf" || rm "$tmpf"
}


# Truncate whole, trailing or middle lines of file.
file_truncate_lines() # 1:file [2:start_line=0 [3:end_line=]]
{
  test -f "$1" || error "file-truncate-lines FILE '$1'" 1
  test -n "$2" && {
    cp $1 $1.tmp
    test -n "$3" && {
      {
        head -n $2 $1.tmp
        tail -n +$(( $3 + 1 )) $1.tmp
      } > $1
    } || {
      head -n $2 $1.tmp > $1
    }
    rm $1.tmp
  } || {
    printf -- "" > $1
  }
}


# Remove leading lines, so that total lines matches LINES
# TODO: rename to truncate-leading-lines
truncate_trailing_lines()
{
  test -n "$1" || error "truncate-trailing-lines FILE expected" 1
  test -n "$2" || error "truncate-trailing-lines LINES expected" 1
  test $2 -gt 0 || error "truncate-trailing-lines LINES > 0 expected" 1
  local lines=$(line_count "$1")
  test $lines > $2 || {
    error "File contains less than $2 lines"
    return
  }
  cp $1 $1.tmp
  tail -n $2 $1.tmp
  head -n +$(( $lines - $2 )) $1.tmp > $1
  rm $1.tmp
}


# Like copy-function, but a generic variant working with explicit numbers or
# grep regexes to determine the span to copy.
copy_where() # Where Span Src-File
{
  test -n "$1" -a -f "$3" || error "copy-where Where/Line Where/Span Src-File" 1
  case "$1" in [0-9]|[0-9]*[0-9] ) start_line=$1 ;; * )
      file_where_grep "$1" "$3" || return $?
      start_line=$line_number
    ;;
  esac
  case "$2" in [0-9]|[0-9]*[0-9] ) span_lines=$2 ;; * )
      file_where_grep "$2" "$3" || return $?
      span_lines=$(( $line_number - $start_line ))
    ;;
  esac
  end_line=$(( $start_line + $span_lines ))
  test $span_lines -gt 0 && {
    tail -n +$start_line $3 | head -n $span_lines
  }
}


# Like cut-function, but a generic version like copy-where is for copy-function.
cut_where() # Where Span Src-File
{
  test -n "$1" -a -f "$3" || error "cut-where Where/Line Where/Span Src-File" 1
  # Get start/span/end line numbers and remove
  copy_where "$@"
  file_truncate_lines "$3" "$(( $start_line - 1 ))" "$(( $end_line - 1 ))"
}


# find '<func>()' line and see if its preceeded by a comment. Return comment text.
func_comment()
{
  test -n "$1" || error "function name expected" 1
  test -n "$2" -a -e "$2" || error "file expected: '$2'" 1
  test -z "$3" || error "surplus arguments: '$3'" 1

  # find function line number, or return 1 ending function for no comment
  grep_line="$(grep -n "^\s*$1()" "$2" | cut -d ':' -f 1)"
  case "$grep_line" in [0-9]* ) ;; * ) return 1 ;; esac

  lines=$(echo "$grep_line" | count_words)
  test $lines -gt 1 && {
    error "Multiple lines for function '$1'"
    return 1
  }

  # find first comment line
  grep_to_first '^\s*#' "$2" "$(( $grep_line - 1 ))"

  # return and reformat comment lines
  source_lines "$2" $first_line $grep_line | sed -E 's/^\s*#\ ?//'
}


# TODO: Return matching lines, going backward starting at <line>
grep_all_before() # File Line Grep
{
  while true
  do
    # get line before function line
    func_leading_line="$(head -n +$2 "$1" | tail -n 1)"
    echo "$func_leading_line" | grep -q "$3" && {
      echo "$func_leading_line"
    } || break
    set -- "$1" "$(( $2 - 1 ))" "$3"
  done
}

header_comment()
{
  read_file_lines_while "$1" 'echo "$line" | grep -qE "^\s*#.*$"' || return $?
  export last_comment_line=$line_number
}

# Echo exact contents of the #-commented file header, or return 1
# backup-header-comment file [suffix-or-abs-path]
backup_header_comment() # Src-File [.header]
{
  test -n "$2" || set -- "$1" ".header"
  fnmatch "/*" "$2" \
    && backup_file="$2" \
    || backup_file="$1$2"
  # find last line of header, add output to backup
  header_comment "$1" > "$backup_file" || return $?
}


# NOTE: its a bit fuzzy on the part after '<id>()' but works

list_functions() # Sh-Files...
{
  test -n "$1" || set -- $0
  for file in $@
  do
    test_out list_functions_head
    trueish "$list_functions_scriptname" && {
      grep '^\s*[A-Za-z0-9_\/-]*().*$' $file | sed "s#^#$file #"
    } ||
      grep '^\s*[A-Za-z0-9_\/-]*().*$' $file
    test_out list_functions_tail
  done
}

find_functions() # Grep Sh-Files
{
  local grep="$1" ; shift
  falseish "first_match" && first_match=
  for file in $@
  do
    grep -q '^\s*'"$grep"'().*$' $file || continue
    echo "$file"
    test -n "$first_match" || break
  done
}

# Return span of lines from Src, starting output at Start-Line and ending
# Span-Lines later, or at before End-Line.
#
#   Span-Lines = End-Line - Start-Line.
#
# If no end is given, then Src must a file and the end is set to the file
# length. Start is set to 0 if empty.
# TODO: cleanup and manage start-line, end-line, span-lines env code.
#
source_lines() # Src Start-Line End-Line [Span-Lines]
{
  test -f "$1"
  test -n "$2" && start_line=$2 || start_line=0
  test -n "$Span_Lines" || Span_Lines=$4
  test -n "$Span_Lines" || {
    end_line=$3
    test -n "$end_line" ||
      end_line=$(count_lines "$1")
    Span_Lines=$(( $end_line - $start_line ))
  }
  tail -n +$start_line $1 | head -n $Span_Lines
}

source_line()
{
  source_lines "$1" "$2" "$(( $2 + 1 ))"
}

# Given a shell script line with a source command to a relative or absolute
# path (w/o shell vars or subshells), replace that line with the actual contents
# of the sourced file.
expand_source_line() # Src-File
{
  test -f "$1" || error "expand_source_line file '$1'" 1
  test -n "$2" || error "expand_source_line line" 1
  local srcfile="$(source_lines "$1" "$2" "" 1 | awk '{print $2}')"
  test -f "$srcfile" || error "src-file $*: '$srcfile'" 1
  file_truncate_lines "$1" "$(( $2 - 1 ))" "$(( $2 ))"
  file_insert_at $1:$(( $2 - 1 )) "$(cat $srcfile )"
  trueish "$keep_source" || rm $srcfile
  info "Replaced line with resolved src of '$srcfile'"
}


# Set line-number to start-line-number of Sh function
function_linenumber() # Func-Name File-Path
{
  test -n "$1" -a -e "$2" || error "function-linenumber FUNC FILE" 1
  file_where_grep "^$1()\(\ {\)\?$" "$2"
  test -n "$line_number" || {
    error "No line-nr for '$1' in '$2'"
    return 1
  }
}


# Set start-line, end-line and span-lines for Sh function ( end = start + span )
function_linerange() # Func-Name Script-File
{
  test -n "$1" -a -e "$2" || error "function-linerange FUNC FILE" 1
  function_linenumber "$@" || return
  start_line=$line_number
  span_lines=$(
      tail -n +$start_line "$2" | grep -n '^}' | head -n 1 | sed 's/^\([0-9]*\):\(.*\)$/\1/'
    )
  end_line=$(( $start_line + $span_lines ))
}


insert_function() # Func-Name Script-File Func-Code
{
  test -n "$1" -a -e "$2" -a -n "$3" || error "insert-function FUNC FILE FCODE" 1
  file_insert_at $2 "$(cat <<-EOF
$1()
{
$3
}

EOF
  ) "
}


# Output the function, including envelope
copy_function() # Func-Name Script-File
{
  test -n "$1" -a -f "$2" || error "copy-function FUNC FILE" 1
  function_linerange "$@" || return
  span_lines=$(( $end_line - $start_line ))
  tail -n +$start_line $2 | head -n $span_lines
}


cut_function()
{
  test -n "$1" -a -f "$2" || error "cut-function FUNC FILE" 1
  # Get start/span/end line numbers and remove
  copy_function "$@"
  file_truncate_lines "$2" "$(( $start_line - 1 ))" "$(( $end_line - 1 ))"
  info "cut-func removed $2 $start_line $end_line ($span_lines)"
}


setup_temp_src()
{
  test -n "$UCONFDIR" || error "metaf UCONFDIR" 1
  mkdir -p "$UCONFDIR/temp-src"
  setup_tmpf "$@" "$UCONFDIR/temp-src"
}


# Isolate function into separate, temporary file.
# Either copy-only, or replaces code with source line to new external script.
copy_paste_function() # Func-Name Src-File
{
  test -n "$1" -a -f "$2" ||
      error "copy-paste-function: Func-Name File expected " $?
  debug "copy_paste_function '$1' '$2' "
  var_isset copy_only || copy_only=1
  test -n "$cp" || {
    test -n "$cp_board" || cp_board="$(get_uuid)"
    cp=$(setup_temp_src .copy-paste-function.sh $cp_board)
    test -n "$cp" || error copy-past-temp-src-required 1
  }
  function_linenumber "$@" || return
  local at_line=$(( $line_number - 1 ))
  trueish "$copy_only" && {
    copy_function $1 $2 > $cp
    info "copy-only (function) ok"
  } || {
    cut_function $1 $2 > $cp
    file_insert_at $2:$at_line "$(cat <<-EOF
. $cp
EOF
    ) "
    info "copy-paste-function ok"
  }
}


copy_paste() # Where/Line Where/Span Src-File
{
  test -n "$1" -a -e "$3" || return $?
  ext=yaml
  debug "copy_paste '$1' '$2' "
  var_isset copy_only || copy_only=1
  test -n "$cp" || {
    test -n "$cp_board" || cp_board="$(get_uuid)"
    cp=$(setup_temp_src .copy-paste.$ext $cp_board)
  }
  case "$1" in [0-9]|[0-9]*[0-9] ) line_number=$1 ;; * )
      file_where_grep "$1" "$3" || return $?
      test -n "$line_number" || return 1
    ;;
  esac
  at_line=$(( $line_number - 1 ))
  trueish "$copy_only" && {
    copy_where $1 $2 $3 > $cp
    info "copy-only ok"
  } || {
    cut_where $1 $2 $3 > $cp
    file_insert_at $3:$at_line "$(cat <<-EOF
# htd source copy-paste: $cp
EOF
    )"
    info "copy-paste ok"
  }
}


expand_sentinel_line() # Src-File Line-Number
{
  test -f "$1" || error "expand_sentinel_line file '$1'" 1
  test -n "$2" || error "expand_sentinel_line line" 1

  local srcfile="$(source_lines "$1" "$2" "" 1 | cut -c26- )"
  test -f "$srcfile" || error "src-file $*: '$srcfile'" 1

  file_truncate_lines "$1" "$(( $2 - 1 ))" "$(( $2 ))"
  file_insert_at $1:$(( $2 - 1 )) "$(cat $srcfile )"
  trueish "$keep_source" || rm $srcfile
  info "Replaced line with resolved src of '$srcfile'"
}


diff_where() # Where/Line Where/Span Src-File
{
  test -n "$1" -a -f "$3" || return $?
  echo
}
