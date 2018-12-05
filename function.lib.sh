#!/bin/sh


# Set line-number to start-line-number of Sh function
function_linenumber() # Func-Name File-Path
{
  test -n "$1" -a -e "$2" || error "function-linenumber FUNC FILE" 1
  file_where_grep "^$1()\(\ {\)\?\(\ \#.*\)\?$" "$2" || return
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
  copy_function "$@" || return
  file_truncate_lines "$2" "$(( $start_line - 1 ))" "$(( $end_line - 1 ))" ||
      return
  std_info "cut-func removed $2 $start_line $end_line ($span_lines)"
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
    test -n "$ext" || ext="$(filenamext "$2")"
    cp=$(setup_temp_src ".copy-paste-function.$ext" "$cp_board")
    test -n "$cp" || error copy-past-temp-src-required 1
  }
  function_linenumber "$@" || return
  local at_line=$(( $line_number - 1 ))

  copy_function "$1" "$2" | grep -q '^\.$' && {
    error "Illegal ed-command in $1:$2 body"
    return 1
  }

  trueish "$copy_only" && {
    copy_function "$1" "$2" > "$cp"
    std_info "copy-only (function) ok"
  } || {
    cut_function "$1" "$2" > "$cp"
    file_insert_at $2:$at_line "$(cat <<-EOF
. $cp
EOF
    ) "
    std_info "copy-paste-function ok"
  }
}

function_start_line()
{
  function_linenumber "$@" || return $?
  echo $line_number
}

function_range()
{
  function_linerange "$@" || return $?
  echo $start_line $span_lines $end_line
}

function_help()
{
  local file= grep_line=
  htd_function_comment "$@"
  htd_function_help
}

function_comment()
{
  test -n "$1" || error "name or string-id expected" 1
  htd_function_comment "$@"
}

function_copy_pase()
{
  test -f "$2" -a -n "$1" -a -z "$3" || error "usage: FUNC FILE" 1
  copy_paste_function "$1" "$2"
  note "Moved function $1 to $cp"
}
