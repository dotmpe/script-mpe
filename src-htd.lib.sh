#!/bin/sh


src_htd_lib_load()
{
  test -n "$sentinel_comment" || sentinel_comment="#"
  lib_load src
}


# Like file-where-grep but set line-numer -= 1
file_where_before()
{
  file_where_grep "$@" || return
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
  file_insert_at "$2" "$line_number" "$3"
}


file_insert_where_after() # 1:where-grep 2:file-path 3:content
{
  local where_line= line_number=
  test -e "$2" || error "no file $2" 1
  test -n "$3" || error "contents required" 1
  file_where_grep "$1" "$2" || return
  test -n "$where_line" || {
    error "missing or invalid file-insert sentinel for where-grep:$1 (in $2)" 1
  }
  file_insert_at "$2" "$line_number" "$3"
}


# Split file at line in two base on match, discard matched line
split_file_where_grep() # Grep [file-or-stdin]
{
  local line_number= tmpf=
  test -e "$2" || {
    test "$2" = "-" ||
      error "split-file-where-grep: file-path or input arg required" 1
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




# Expand include-lines but don't modify files
expand_include_sentinels() # Src...
{
  for src in "$@"
  do
    grep -n $sentinel_comment'include\ ' "$src" | while IFS="$IFS:" read -r num match file
    do
      # NOTE: should not rewrite file while grepping it
      #expand_line "$src" "$num" "$file"
      source_lines "$src" "0" "$(( $num - 1 ))"
      trueish "$add_sentinels" && echo "$sentinel_comment start of $src" || true
      deref_include "$file" "$src"
      trueish "$add_sentinels" && echo "$sentinel_comment end of $src" || true
      source_lines "$src" "$(( $num + 1 ))"
    done
  done
}


# Resolve contents for given include directive parameter
deref_include() # Include-Spec
{
  case "$1" in
      "<"*">" ) set -- "$scriptpath/$1" "$2" ;;
      "\""*"\"" ) set -- "$(eval echo $1)" "$2" ;;
  esac
  note "Include '$1' '$2'"
  case "$1" in
      /* ) cat "$1" ;;
      * ) cat "$(dirname "$2")/$1" ;;
  esac
}




setup_temp_src()
{
  test -n "$UCONFDIR" || error "metaf UCONFDIR" 1
  mkdir -p "$UCONFDIR/_temp-src"
  setup_tmpf "$@" "$UCONFDIR/_temp-src"
}


copy_paste() # Where/Line Where/Span Src-File
{
  test -n "$1" -a -e "$3" || return $?
  debug "copy_paste '$1' '$2' "
  sh_isset copy_only || copy_only=1
  test -n "$cp" || {
    test -n "$cp_board" || cp_board="$(get_uuid)"
    test -n "$ext" || ext=$(filenamext "$3")
    cp=$(setup_temp_src ".copy-paste.$ext" "$cp_board")
  }
  case "$1" in [0-9]|[0-9]*[0-9] ) line_number=$1 ;; * )
      file_where_grep "$1" "$3" || return $?
      test -n "$line_number" || return 1
    ;;
  esac
  at_line=$(( $line_number - 1 ))
  trueish "$copy_only" && {
    copy_where $1 $2 $3 > $cp
    std_info "copy-only ok"
  } || {
    cut_where $1 $2 $3 > $cp
    file_insert_at $3:$at_line "$(cat <<-EOF
# htd source copy-paste: $cp
EOF
    )"
    std_info "copy-paste ok"
  }
}

# TODO: diff-where
diff_where() # Where/Line Where/Span Src-File
{
  test -n "$1" -a -f "$3" || return $?
  echo
}

# Replace include directives with file content, using two sed's and some subproc
# per include line in between.
expand_preproc()
{
  # Get include lines, reformat to sed commands, and execute
  $gsed -n 's/^#'$1'\ \(.*\)$/\1/gp' "$2" |
  while read -r include
  do printf -- '/^#'$1'\ %s/r %s\n' \
      "$(match_grep "$include")" \
      "$(eval echo $include)"
  done | $gsed -f - "$2"
}
