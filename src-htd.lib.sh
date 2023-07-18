#!/bin/sh


src_htd_lib__load ()
{
  true "${CACHE_DIR:=${STATUSDIR_ROOT:?}cache}"
  true "${sentinel_comment:="#"}"
  true "${gsed:=sed}"
}


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
  test -n "${1-}" || error "content expected" 1
  echo "$1" | grep -q '^\.$' && {
    error "Illegal ed-command in input stream"
    return 1
  }

  # use ed-script to insert second file into first at line
  # Note: this loses trailing blank lines
  # XXX: should not have ed period command. Cannot sync this function, file-insert-at
  stderr info "Inserting at $file_name:$line_number"
  echo "${line_number}a
$1
.
w" | ed -s $file_name
}


# Replace one entire line using Sed.
file_replace_at() # ( FILE:LINE | ( FILE LINE ) ) INSERT
{
  test -n "$*" || error "arguments required" 1
  test -z "${4-}" || error "too many arguments" 1

  local file_name= line_number=

  fnmatch *:[0-9]* "$1" && {
    file_name=$(echo $1 | cut -f 1 -d :)
    line_number=$(echo $1 | cut -f 2 -d :)
    shift 1
  } || {
    file_name=$1; shift 1
    line_number=$1; shift 1
  }

  test -e "$file_name" || error "no file: $file_name" 1
  test -n "$line_number" || error "no line_number: $file_name: '$1'" 1
  test -n "$1" || error "nothing to insert" 1

  set -- "$( echo "$1" | sed 's/[\#&\$]/\\&/g' )"
  $gsed -i $line_number's#.*#'"$1"'#' "$file_name"
}


# Quietly get the first grep match' into where-line and parse out line number
file_where_grep() # 1:where-grep 2:file-path
{
  test -n "${1-}" || {
    error "where-grep arg required"
    return 1
  }
  test -e "$2" -o "$2" = "-" || {
    error "file-where-grep: file-path or input arg required '$2'"
    return 1
  }
  where_line="$(grep -n "$@" | head -n 1)"
  line_number=$(echo "$where_line" | sed 's/^\([0-9]*\):\(.*\)$/\1/')
}


# Like file-where-grep but grep starting at and after start-line if given.
file_where_grep_tail() # 1:where-grep 2:file-path [3:start-line]
{
  test -n "${1-}" || error "where-grep arg required" 1
  test -e "${2-}" || error "file expected '$1'" 1
  test $# -le 3 || return
  test -n "${3-}" && {
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
  from_line=$3
  while true
  do
    tail -n +$3 "$2" | head -n 1 | grep -q "$1" || break
    set -- "$1" "$2" "$(( $3 - 1 ))"
  done
  test $from_line -gt $3 || return
  first_line=$3
}


# Like grep-to-last but go backward matching for Grep.
grep_to_previous() # 1:Grep 2:File-Path 3:Line
{
  from_line=$3
  while true
  do
    tail -n +$3 "$2" | head -n 1 | grep -q "$1" || break
    set -- "$1" "$2" "$(( $3 + 1 ))"
  done
  prev_line=$3
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


# Truncate whole, trailing or middle lines of file.
file_truncate_lines() # 1:file [2:start_line=0 [3:end_line=]]
{
  test -f "${1-}" || error "file-truncate-lines FILE '$1'" 1
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


# find '<func>()' line and see if its preceeded by a comment. Return comment text.
func_comment()
{
  test -n "${1-}" || error "function name expected" 1
  test -n "${2-}" -a -e "${2-}" || error "file expected: '$2'" 1
  test -z "${3-}" || error "surplus arguments: '$3'" 1

  # find function line number, or return 1 ending function for no comment
  grep_line="$(grep -n "^\s*$1()" "$2" | cut -d ':' -f 1)"
  case "$grep_line" in [0-9]* ) ;; * ) return 1 ;; esac

  lines=$(echo "$grep_line" | count_words)
  test ${lines-0} -gt 1 && {
    error "Multiple lines for function '$1'"
    return 1
  }

  # find first comment line
  grep_to_first '^\s*#' "$2" "$(( $grep_line - 1 ))"

  # return and reformat comment lines
  source_lines "$2" ${first_line-0} $grep_line | sed -E 's/^\s*#\ ?//'
}

grep_head_comment_line()
{
  head_comment_line="$($ggrep -m 1 '^[[:space:]]*# .*\..*$' "$1")" || return
  echo "$head_comment_line" | sed 's/^[[:space:]]*# //g'
}

# Get first proper text with period character from head-comment, ie. retrieve
# single line
# non-directive, non-header with eg. description line. See alt. grep-list-head.
read_head_comment()
{
  local r=''

  # Scan #-diretives to first proper comment line
  read_lines_while "$1" 'echo "$line" | grep -qE "^\s*#[^ ]"' || r=$?
  test -n "$line_number" || return 9

  # If no line matched start at firstline
  test -n "$r" && first_line=1 || first_line=$(( $line_number + 1 ))

  # Read rest, if still commented.
  read_lines_while "$1" 'echo "$line" | grep -qE "^\s*#(\ .*)?$"' $first_line || return

  width_lines=$line_number
  last_line=$(( $first_line + $width_lines - 1 ))
  lines_slice $first_line $last_line "$1" | $gsed 's/^\s*#\ \?//'
}

# Echo exact contents of the #-commented file header, or return 1
# backup-header-comment file [suffix-or-abs-path]
backup_header_comment() # Src-File [.header]
{
  test -f "${1-}" || return
  test -n "${2-}" || set -- "$1" ".header"
  fnmatch "/*" "$2" \
    && file_backup="$2" \
    || file_backup="$1$2"
  # find last line of header, add output to backup
  read_head_comment "$1" >"$file_backup" || return $?
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
source_lines () # ~ Src Start-Line End-Line [Span-Lines]
{
  test -f "$1" || return
  test -n "${2-}" && start_line=$2 || start_line=0
  test -n "${Span_Lines-}" || Span_Lines=${4-}
  test -n "$Span_Lines" || {
    end_line=$3
    test -n "$end_line" || end_line=$(count_lines "$1")
    Span_Lines=$(( $end_line - $start_line ))
  }
  tail -n +$start_line $1 | head -n $Span_Lines
}

source_line() # Src Start-Line
{
  source_lines "$1" "$2" "$(( $2 + 1 ))"
}

# Given a shell script line with a source command to a relative or absolute
# path (w/o shell vars or subshells), replace that line with the actual contents
# of the sourced file.
expand_source_line() # Src-File Line
{
  test -f "${1-}" || error "expand_source_line file '$1'" 1
  test -n "${2-}" || error "expand_source_line line" 1
  local srcfile="$(source_lines "$1" "$2" "" 1 | awk '{print $2}')"
  test -f "$srcfile" || error "src-file $*: '$srcfile'" 1
  expand_line "$@" "$srcfile" || return
  trueish "${keep_source-0}" || rm $srcfile
  info "Replaced line with resolved src of '$srcfile'"
}


# See expandline, uses and removes 'srcfile' if requested
expand_srcline()
{
  test -f "$srcfile" || error "src-file $*: '$srcfile'" 1
  expand_line "$@" "$srcfile"
  trueish "${keep_source-0}" || rm $srcfile
  info "Replaced line with resolved src of '$srcfile'"
}


# Strip sentinel line and insert external file
expand_line() # Src-File Line Include-File
{
  test $# -eq 3 || return
  file_truncate_lines "$1" "$(( $2 - 1 ))" "$2" &&
  file_insert_at $1:$(( $2 - 1 )) "$(cat "$3")"
}


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
  test -n "${1:-}" -a -f "${2:-}" || error "copy-function FUNC FILE" 1
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
  info "cut-func removed $2 $start_line $end_line ($span_lines)"
}


# Expand include-lines but don't modify files
expand_include_sentinels() # Src...
{
  for src in "$@"
  do
    grep -n $sentinel_comment'include\ ' "$src" |
        while IFS="$IFS:" read -r num match file
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
  test -n "$UCONF" || error "metaf UCONF" 1
  mkdir -p "$UCONF/_temp-src"
  setup_tmpf "$@" "$UCONF/_temp-src"
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
    info "copy-only (function) ok"
  } || {
    cut_function "$1" "$2" > "$cp"
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

# List values for include-type pre-processor directives from file and all
# included files (recursively).
preproc_includes_list () # ~ <Resolver-> <File>
{
  local resolve=${1:-resolve_fileref}; shift 1
  preproc_recurse preproc_includes $resolve 'echo "$file"' "$@"
}

preproc_recurse () # ~ <Generator> <Resolve-fileref> <Action-cmd>
{
  local select="${1:?}" resolve="${2:?}" act="${3:?}"; shift 3

  grep_f=-HnPo "$select" "$@" | while IFS=$':\n' read -r srcf srcl ref
  do
    file=$($resolve "$ref" "$srcf")
    eval "$act"
    preproc_recurse "$select" "$resolve" "$act" "$file" || true
  done
}

# Resolve include reference to use,
#from file, echo filename with path. If cache=1 and
# this is not a plain file (it has its own includes), give the path to where
# the fully assembled, pre-processed file should be instead.
resolve_fileref () # [cache=0,cache_key=def] ~ <Ref> <From>
{
  local fileref

  # TODO: we should look-up these on some (lib) path
  #fnmatch "<*>" "$1"
  #fnmatch '"*"' "$1"

  # Ref must be absolute path (or var-ref), or we prefix the file's basedir
  fnmatch "[/~$]*" "$1" \
      && fileref=$1 \
      || fileref=$(dirname -- "$2")/$1 # make abs path

  #file="$(eval "echo \"$fileref\"" | sed 's#^\~/#'"${HOME:?}"'/#')" # expand vars, user
  file=$(os_normalize "${fileref/#~\//${HOME:?}/}") &&
  test -e "$file" || {
    $LOG warn "" "Cannot resolve reference" "ref:$1 file:$file"
    return 9
  }
  echo "$file"
# FIXME:
  #{ test ${cache:-0} -eq 1 && grep -q '^ *#'"${3:?}"' ' "$file"
  #} \
  #    && echo "TODO:$file" \
  #    || echo "$file"
}

preproc_lines () # [grep_f] ~ <Dir-match> [<File|Grep-argv>] # Select only preprocessing lines
{
  local grep_re=${1:-"\K[\w].*"}; test $# -eq 0 || shift
  grep ${grep_f:--Po} '^#'"$grep_re" "$@"
}

preproc_includes () # [grep_f] ~ [<File|Grep-argv>] # Select args for preproc lines
{
  preproc_lines 'include \K.*' "$@"
}

# Recursively resolve and list just the include directives
preproc_includes_enum () # ~ <Resolver-> <File|Grep-argv...>
{
  local resolve=${1:-resolve_fileref}; shift 1
  preproc_recurse preproc_includes $resolve 'echo -e "$srcf\t$srcl\t$ref\t$file"' "$@"
}

preproc_expand () # ~ <Resolver-> <File>
{
  # TODO: fix caching
  preproc_expand_1_sed "${@:?}"

  # TODO: apply recursively
  #preproc_expand_2_awk "${@:?}"
}

# Replace include directives with file content, using two sed's and two
# functions to resolve and dereference the file. See preproc-resolve-sedscript
preproc_expand_1_sed () # ~ <Resolver-> <File|Grep-argv...>
{
  local lk=${lk:-}:expand-preproc:sed1 sc
  preproc_expand_1_sed_script "$@" || return
  ${preproc_read_include:-read_nix_data} "${2:?}" | {
    "${gsed:?}" -f "$sc" - ||
      $LOG error $lk "Error executing sed script" "E$?:($#):$*" $? || return
  }
}
preproc_expand_1_sed_script ()
{
  local fn=${2//[^A-Za-z0-9\.:-]/-}
  sc=${CACHE_DIR:?}/$fn.sed1
  # Get include lines, reformat to sed commands, and execute sed-expr on input
  local resolve=${1:-resolve_fileref}
  preproc_resolve_sedscript "$resolve" "${2:?}" >| "$sc" ||
      $LOG error $lk "Error generating sed script" "E$?:($#):$*" $? || return
}

preproc_expand_2_awk () # ~ <Directive-tag> <File>
{
  # Awk does not leave sentinel line.
  awk -v HOME=$HOME -v v=${verbosity:-${v:-3}} '
    function insert_file (file)
    {
        if (v > 4)
            print "Reading \""file"\" for "FILENAME"..." >> "/dev/stderr"
        gsub(/~\//,HOME"/",file)
        if (system("[ -s \""file"\" ]") == 1) {
            if (v > 2)
                print "No such include for "FILENAME" named "file >> "/dev/stderr"
            exit 4
        }
        if (file in sources) {
            if (v > 2)
                print "Recursion from "FILENAME" into already loaded "file >> "/dev/stderr"
            exit 3
        }
        sources[file]=1
        while (getline line < file)
            print line
        close(file)
        if (v > 5)
            print "Closed \""file"\"" >> "/dev/stderr"
    }
    /#'"${1:-include}"'/ { insert_file($2); next; }
  ' "${2:?}"
}

preproc_hasdir () # ~ <Dir-match> <File|Grep-argv...>
{
  local dir=${1:?}; shift
  grep -q '^[ \t]*#'"$dir"' ' "$@"
}

# Generate Sed script to assemble file with include preproc directives.
# Like preproc
preproc_resolve_sedscript () # ~ <Resolver> [<File>] # Generate Sed script
{
  local resolve=${1:-resolve_fileref}; shift 1
  preproc_recurse preproc_includes $resolve preproc_resolve_sedscript_item "$@"
}

preproc_resolve_sedscript_item ()
{
  ref_re="$(match_grep "$ref")"
  test "${preproc_read_include:-file}" = file && {
    printf '/^[ \\t]*#include\ %s/r %s\n' "$ref_re" "$file"
    printf 's/^[ \\t]*#include\ \(%s\)/#from\ \\1/\n' "$ref_re"
  } || {
    printf '/^[ \\t]*#include\ %s/e %s' "$ref_re" "${preproc_read_include:?}"
    printf ' "%s"' "$ref" "$file" "$srcf" "$srcl"
    printf '\n'
    printf 's/^[ \\t]*#include\ \(%s\)/#from-include\ \\1/\n' "$ref_re"
  }
  # XXX: cleanup directives
  #printf 's/^[ \t]*#\(include\ %s\)/#-\1/g\n' "$ref_re"
  #printf 's/^#include /#included /g\n'
}

# Sync: src.lib.sh
