#!/bin/sh

## Htd ctx cleanup for OS wip: files, paths.


os_htd_lib_load()
{
  : "${uname:="$(uname -s)"}"
  : "${os:="$(uname -o)"}"
}

os_htd_lib_init()
{
  test "${os_htd_lib_init-}" = "0" || {
    test -n "$LOG" -a \( -x "$LOG" -o "$(type -t "$LOG")" = "function" \) \
      && os_htd_lib_log="$LOG" || os_htd_lib_log="$INIT_LOG"
    test -n "$os_htd_lib_log" || return 108
    $os_htd_lib_log debug "" "Initialized os-htd.lib" "$0"
  }
}


abbrev_rename()
{
  while read -r oldpath junk newpath
  do
    local idx=1
    while test "$(echo "$oldpath" | cut -c 1-$idx )" = "$(echo "$newpath" | cut -c 1-$idx )"
    do
        idx=$(( $idx + 1 ))
    done
    local end=$(( $idx - 1 ))
    echo "Backed up path: $( echo $oldpath | cut -c 1-$end 2>/dev/null){$(echo $oldpath | cut -c $idx- 2>/dev/null) => $(echo $newpath | cut -c $idx- 2>/dev/null)}"
  done
}

# if not exists, create directories and touch file for each given path arg
# to print only existing files see filter_files
assert_files ()
{
  # shellcheck disable=SC2068
  for fn in $@
  do
    test -n "$fn" || continue
    test -e $fn || {
      test -z "$(dirname $fn)" || mkdir -vp $(dirname $fn)
      touch $fn
    }
  done
}

# A simple, useful wrapper for awk prints entire line, one column or other
# AWK print value if AWK expression evaluates true.
awk_line_select () # (s) ~ <Awk-If-Expr> [<Out>]
{
  awk '{ if ( '"${1:?"An expression is required"}"' ) { print '"${2:-"\$0"}"' } }'
}

# Go over pathnames, and compare with file. Return non-zero on first file with differences.
diff_files() # File-Path Path-Name...
{
  #param 'FILE OTHER...'
  # TODO: group 'OS:Diff'
  #group 'OS-Htd:Diff'
  test $# -gt 1 -a -f "$1" || return 98

  local from="$1"
  shift
  for path in "$@"
  do
    test -f "$path" || path="$path/$1"
    diff -bqr "$1" "$path" && continue
  done
}
# Sh-Copy: HT:tools/u-s/parts/diff-files.inc.sh vim:ft=bash:

disk_usage()
{
  test -n "$1" || set -- "." "$2"
  test -n "$2" || set -- "$1" "h"
  du -$2s $1 | awk '{print $1}'
}

# Number lines from read-nix-style-file by src, filter comments after.
enum_nix_style_file ()
{
  cat_f=-n read_nix_style_file "$@" '^[0-9]*:\s*(#.*|\s*)$' || return
}

# Abort shell at location.
# XXX: This is a pretty effective way of aborting Bash. I wonder if there is
# another way to get it.
# Calling a function is not very useful, but this we can eval in-place. It can
# be pretty short too:
#
#   eval `sh_gen_abort E123 "Something went wrong"`
#
sh_gen_abort () # ~ <Key-> <Msg-> # Generate script to abort shell
{
  local k=${1:-Abort}; k=${k//[^A-Za-z0-9_]/_}; echo "$k=;:\ \"\${$k:?\"${2-}\"}\""
}

# make numbered copy, see number-file
file_backup () # ~ <Name> [<.Ext>]
{
  test -s "${1:?}" || return
  action="cp -v" file_number "${@:?}" | abbrev_rename
}

# Add number to filename, provide extension to split basename before adding suffix
file_number () # [action=mv] ~ <Name> [<.Ext>]
{
  local dir=$(dirname -- "${1:?}") cnt=1 base=$(basename -- "$1" ${2-}) dest

  while true
  do
    dest=$dir/$base-$cnt${2-}
    test -e "$dest" || break
    cnt=$(( $cnt + 1 ))
  done

  local action="${action:-echo}"
  $action "$1" "$dest"
}

# rename to numbered file, see number-file
file_rotate () # ~ <Name> [<.Ext>]
{
  test -s "${1:?}" || return
  action="mv -v" file_number "${@:?}" | abbrev_rename
}

# Use `stat` to get birth time (in epoch seconds)
filebtime() # ~ <File-path>
{
  local flags=- ; file_stat_flags
  case "${uname:?}" in
    Darwin )
        trueish "${file_names-}" && pat='%N %B' || pat='%B'
        stat -f "$pat" $flags "$1" || return 1
      ;;
    Linux )
        # XXX: %N is deref-file
        trueish "${file_names-}" && pat='%N %W' || pat='%W'
        stat -c "$pat" $flags "$1" || return 1
      ;;
    * ) error "filebtime: $1?" 1 ;;
  esac
}

# Use `stat` to get inode change time (in epoch seconds)
filectime() # ~ <File-path>
{
  while test $# -gt 0
  do
    case "${uname:?}" in
      Darwin )
          stat -L -f '%c' "$1" || return 1
        ;;
      Linux | CYGWIN_NT-6.1 )
          stat -L -c '%Z' "$1" || return 1
        ;;
      * ) $os_lib_log error "os" "filectime: $uname?" "" 1 ;;
    esac; shift
  done
}

filextensions () # ~ <File-path>
{
  test -e "$1" || error "expected existing path <$1>" 1
  case "${uname:?}" in

    Darwin ) file -b --mime-type "$1" ;;
    Linux ) file -bi "$1" ;;

    * ) error "No file MIME-type on $uname" 1 ;;

  esac
}

# Description of file contents, format
fileformat () # ~ <File-path>
{
  local flags= ; file_tool_flags
  case "${uname:?}" in
    Darwin | Linux )
        file -${flags} "$1" || return 1
      ;;
    * ) error "fileformat: $uname?" 1 ;;
  esac
}

# Use `stat` to get modification time (in epoch seconds)
filemtime() # ~ <File-path <...>>
{
  local flags=- ; file_stat_flags
  while test $# -gt 0
  do
    case "${uname:?}" in
      Darwin )
          trueish "${file_names-}" && pat='%N %m' || pat='%m'
          stat -f "$pat" $flags "$1" || return 1
        ;;
      Linux | CYGWIN_NT-6.1 )
          trueish "${file_names-}" && pat='%N %Y' || pat='%Y'
          stat -c "$pat" $flags "$1" || return 1
        ;;
      * ) $os_lib_log error "os" "filemtime: $uname?" "" 1 ;;
    esac; shift
  done
}

# Use `file` to get mediatype aka. MIME-type
filemtype () # ~ <File-path>
{
  local flags= ; file_tool_flags
  case "${uname:?}" in
    Darwin )
        file -${flags}I "$1" || return 1
      ;;
    Linux )
        file -${flags}i "$1" || return 1
      ;;
    * ) error "filemtype: $uname?" 1 ;;
  esac
}

# Use `stat` to get size in bytes
filesize () # ~ <File-path <...>>
{
  local flags=- ; file_stat_flags
  while test $# -gt 0
  do
    case "${uname:?}" in
      Darwin )
          stat -L -f '%z' "$1" || return 1
        ;;
      Linux | CYGWIN_NT-6.1 )
          stat -L -c '%s' "$1" || return 1
        ;;
      * ) $os_lib_log error "os" "filesize: $uname?" "" 1 ;;
    esac; shift
  done
}

filesizesum ()
{
  sum=0
  while read -r file
  do
      sum=$(( $sum + $(filesize "$file" | tr -d '\n' ) ))
  done
  echo $sum
}

# Strip comments lines, including pre-proc directives and empty lines.
filter_content_lines () # (s) ~ [<Marker-Regex>] # Remove marked or empty lines from stream
{
  grep -v '^\s*\('"${1:-"#"}"'.*\|\s*\)$'
}

filter_dir ()
{
  test -d "$1" || return 0
  echo "$1"
}

filter_dirs ()
{
  act=filter_dir s="" p="" foreach_do "$@"
}

filter_empty_lines () # (s) ~ # Remove empty lines from stream
{
  grep -v '^\s*$'
}

filter_file ()
{
  test -f "$1" || return 0
  echo "$1"
}

filter_files ()
{
  act=filter_file s="" p="" foreach_do "$@"
}

# Strip comments, including line-continuations.
# See line-comment-conts-collapse to transform them.
filter_line_comments () # (s) ~ [<Marker-Regex>]
{
  sed ':a; N; $!ba; s/'"${1:-"#"}"'[^\\\n]*\(\\\n[^\\\n]*\)*\n//g'
}

find_broken_symlinks () # ~ DIR
{
  test $# -gt 0 || set -- .
  test $# -eq 1 || return 64
  find "$1" -type l ! -exec test -e {} \; -print
}

find_filter_broken_symlinks () # ~ DIR
{
  test $# -gt 0 || set -- .
  test $# -eq 1 || return 64
  find "$1" -type l -exec test -e {} \; -print
}

find_num () # ~ DIR NAME [NUM]
{
  test -n "${1-}" -a -n "${2-}" || error "find-num '$*'" 1
  test -n "${3-}" || set -- "$@" 1
  local c=0
  find "$1" -iname "$2" | while read -r path
  do
    c=$(( $c + 1 ))
    test $c -le $3 || return 1
    echo "$path"
  done
}

find_one () # ~ DIR NAME
{
  test $# -eq 2 || return 64
  find_num "$@" 1
}

# Go over arguments and echo. If no arguments given, or on argument '-' the
# standard input is cat instead or in-place respectively. Strips empty lines.
# (Does not open filenames and read from files). Multiple '-' arguments are
# an error, as the input is not buffered and rewounded. This simple setup
# allows to use arguments as stdin, insert arguments-as-lines before or after
# stdin, and the pipeline consumer is free to proceed.
#
# If this routine is given no data is hangs indefinitely. It does not have
# indicators for data availble at stdin.
foreach () # [(s)] ~ ['-' | <Arg...>]
{
  {
    test -n "$*" && {
      while test $# -gt 0
      do
        test "$1" = "-" && {
          # XXX: echo foreach_stdin=1
          cat -
          # XXX: echo foreach_stdin=0
        } || {
          printf -- '%s\n' "$1"
        }
        shift
      done
    } || cat -
  } | grep -v '^$'
}

# Extend rows by mapping each value line using act, add result tab-separated
# to line. See foreach-do for other details.
foreach_addcol ()
{
  foreach "$@" | read_addcol
}

# Read `foreach` lines and act, default is echo ie. same result as `foreach`
# but with p(refix) and s(uffix) wrapped around each item produced. The
# unwrapped loop-var is _S.
# The return status of action is not handled.
foreach_do ()
{
  test -n "${p-}" || local p= # Prefix string
  test -n "${s-}" || local s= # Suffix string
  test -n "${act-}" || local act="echo"
  foreach "$@" | while ${read:-read -r} _S ; do S="$p$_S$s" && $act "$S" ; done
}

# See -addcol and -do.
foreach_inscol ()
{
  test -n "${p-}" || local p= # Prefix string
  test -n "${s-}" || local s= # Suffix string
  test -n "${act-}" || local act="echo"
  foreach "$@" | while ${read:-read -r} _S
    do S="$p$_S$s" && printf -- '%s\t%s\n' "$($act "$S")" "$S" ; done
}

foreach_line_do ()
{
  while read -r args
  do "$@" $args || return; done
}

# Execute act/no-act based on expression match, function/command or shell statement
# Types are [g]lob-match, grep-[r]egex, local-cmd e[x]pression or [e]val expression.
# Subjects (stdin lines) may be provided as arguments instead, and to do
# additional prefix/suffix addition on subjects (and only there).
foreach_match () # [type_=(grxe) expr_= act=echo no_act=/dev/null p= s=] [Subject...]
{
  test "$1" != "-" || shift
  test -n "$expr_" || { type_=g expr_='*'; }
  test -n "$act" || act="echo"
  test -n "$no_act" || no_act=/dev/null
  # Read arguments or lines from stdin
  { test -n "$*" && { for a in "$@"; do printf -- '%s\n' "$a"; done; } || cat -
  } | while read -r _S ; do S="$p$_S$s"
  # NOTE: Allow inline comments or processing instructions passthrough
  fnmatch "#*" "$S" && { echo "$S" ; continue; }
  # Execute, echo on success or do nothing except print on stdout in debug-type
  case "$type_" in
      g ) fnmatch "$expr_" "$S" ;;
      r ) echo "$S" | grep -q "$expr_" ;;
      x ) $expr_ "$S" ;;
      e ) eval "$expr_" ;;
      * ) error "foreach-expr-type? '$type_'" 1 ;;
  esac && $act "$S" || $no_act "$S" ; done
}

# Split expression type from argument and set envs expr_/type_
foreach_match_setexpr () # [Type:]Expression
{
  test -n "$1" || set -- '*'
  expr_="$1"
  fnmatch "*:*" "$expr_" && {
    type_="$(echo "$expr_" | cut -c1)"
    expr_="$(echo "$expr_" | sed 's/^[^:]*://')"
  } || {
    type_=g
  }
  std_info "Mode: $type_, Expression: '$expr_'"
}

foreach_sub_col () # ~ <Col-Nr> <Sub-Cmd>
{
  awk ' BEGIN { mysub = "'"$2"'" }
        {
            col = $'$1'
            print col |& mysub
            mysub |& getline out
            close(mysub)
            $'$1' = out
            print
        }
    '
}

forone_do () # ~ <Cmd>
{
  read forone
  "$@" "$forone"
}

# Resolve all symlinks in subtree, return a list with targets
get_targets ()
{
  test -n "$1" || set -- /srv
  # Assume
  find $1 -type l | while read -r link
  do
    test -e "$link" || continue
    target=$(readlink $link)
    normalize_relative $(dirname $link)/$target
  done | sort -u
}

# XXX: Go to dir and set OLDPWD, but only if not already there
#go_to_dir()
#{
#  test -n "$1" || set -- "."
#  test "$1" = "." || cd "$1"
#  # -o "$(pwd -P)" = "$(cd "$1" && pwd -P)" || cd $1
#}

# Change cwd to parent dir with existing local path element (dir/file/..) $1, leave go_to_before var in env.
go_to_dir_with () # ~ <Local-Name>
{
  test -n "$1" || error "go-to-dir: Missing filename arg" 1

  # Find dir with metafile
  go_to_before=.
  while true
  do
    test -e "$1" && break
    go_to_before=$(basename -- "$PWD")/$go_to_before
    test "$PWD" = "/" && break
    cd ..
  done

  test -e "$1" || return 1
}

ignore_sigpipe ()
{
  ignore_stat eq 141 # For bash: 128+signal where signal=SIGPIPE=13
}

ignore_stat () # ~ <Test> <Int> # Ignore status lt/le/eq/gt/ge or return
{
  local r=$?
  test $r -${1:-eq} ${2:?} || return $r
}

isemptydir ()
{
  test -d "$1" -a "$(echo $1/*)" = "$1/*"
}

isnonemptydir ()
{
  test -d "$1" -a "$(echo $1/*)" != "$1/*"
}

# Read $line as long as CMD evaluates, and increment $line_number.
# CMD can be silent or verbose in anyway, but when it fails the read-loop
# is broken.
lines_count_while_eval () # CMD
{
  test $# -gt 0 || return

  line_number=0
  while read ${read_f-"-r"} line
  do
    eval $1 || break
    line_number=$(( $line_number + 1 ))
  done
  test $line_number -gt 0 || return
}

# Offset content from input/file to line-based window.
lines_slice () # [First-Line] [Last-Line] [-|File-Path]
{
  test -n "${3-}" || error "File-Path expected" 1
  test "$3" = "-" && set -- "$1" "$2"
  test -n "$1" && {
    test -n "$2" && { # Start - End: tail + head
      tail -n "+$1" "$3" | head -n $(( $2 - $1 + 1 ))
      return $?
    } || { # Start - ... : tail
      tail -n "+$1" "$3"
      return $?
    }

  } || {
    test -n "$2" && { # ... - End : head
      head -n "$2" "$3"
      return $?
    } || { # Otherwise cat
      cat "$3"
    }
  }
}

files_exist ()
{
  false
}

# Expand pattern, ignoring non-existant expansions. TODO: non-zero for empty
files_existing () # ~ <Shell-filename-pattern...>
{
  eval "echo $*" | tr ' ' '\n' | filter_files
}

files_lock()
{
  local id=$1
  shift
  std_info "Reserving resources for session $id ($*)"
  for f in "$@"
  do
    test -e "$f.lock" && {
      lock="$(head -n 1 $f.lock | awk '{print $1}')"
      test "$lock" = "$id" && echo $f ||
        warn "Ignored existing lock $lock for $f"
    } || {
      assert_files $f
      echo $f && echo $id > $f.lock
    }
  done
}

# Verify locks
files_locked ()
{
  local id=$1
  shift
  for f in "$@"
  do
    test -e "$f.lock" || return 2
    test "$(head -n 1 $f.lock | awk '{print $1}')" = "$id" || return 1
  done
}

files_unlock()
{
  local id=$1 lock=
  shift
  std_info "Releasing resources from session $id ($*)"
  for f in "$@"
  do
    test -e "$f.lock" && {
      lock="$(head -n 1 $f.lock | awk '{print $1}')"
      test "$lock" = "$id" && {
        rm $f.lock
        test -e "$f" || continue
        echo $f
      }
    } || continue
  done
}

# Collapse only line-comment-continuations completely.
# See also line-conts-collapse, or filter-line-comments.
line_comment_conts_collapse () # (s) ~ [<Marker-re>]
{
  # This recursively applies the s command by going from bb back to :b until
  # it finds no further line-continuation at the end of the comment
  sed -E ':a;N;$!ba; :b;/'"${1:-"#"}"'[^\\\n]*\\\n/{
        s/('"${1:-"#"}"'[^\\\n]*)(\\\n([^\\\n]*))/\1\3/g; bb;
    }'
}

line_comments_collapse () # (s) ~ [<Marker-re>] # Collapse subsequent line-comments into one.
{
  local m=${1:-"# "}
  sed -E ':a;N;$!ba; :b;/'"$m"'[^\n]*\n'"$m"'/{
        s/('"$m"'[^\n]*)(\n'"$m"'([^\n]*))/\1 \3/g; bb;
    }'
}

# Extract line-continuation block (without reformatting). Returns non-zero if
# reading ended before reading one entire line continuation.
line_cont_extract () # (s) ~ # Echo all continuation lines plus end line and return
{
  read_while grep '\\$' || return
  echo "$line"
}

# Extract first line-continuation block.
# See line-cont-scan and line-cont-extract.
line_cont_read_first () # (s) ~ # Scan for and then echo lines in continuation
{
  line_cont_scan || return
  echo "$line"
  line_cont_extract
}

# Read until first line-continuation. Returns non-zero if reading ended before
# reading one line continuation.
line_cont_scan () # (s) ~ # Read (silently) until at a continuation line
{
  read_while not grep -q '\\$'
}

# Replace every line-end with continuation (and surrounding spaces) with a single space.
line_conts_collapse () # (s) ~ # Replace line-continuations with space
{
  sed ':a; N; $!ba; s/ *\\\n */ /g'
}

# Insert string at empty positions in space/tab/... separated lines
line_fields_replace_empty () # ~ [<Field-separator>] [<Substitute>]
{
  line_fields_replace_value "${1:-}" "" "${2:?}"
}

line_fields_replace_value () # ~ [<Field-separator>] <Match-> [<Substitute->]
{
  local fs=${1:-"\t"} m=${2:-} s=${3:-}
  test $# -eq 0 || shift
  test $# -eq 0 || shift
  test $# -eq 0 || shift
  sed ':a; /\('"$fs"'\|^\)'"$m"'\('"$fs"'\|$\)/{
        s/\('"$fs"'\|^\)'"$m"'\('"$fs"'\|$\)/\1'"$s"'\2/g; ba;
      }' "$@"
}

linux_boottime ()
{
  echo $(( $($gdate +"%s" ) + $(linux_uptime) ))
}

linux_uptime ()
{
  cut -d' ' -f1 /proc/uptime
}

mkrlink()
{
  test $# -gt 1 -a -n "$1" || return
  # TODO: find shortest relative path
  ln -vs "$(basename "$1")" "${2:-"$PWD/"}"
}

normalize_relative()
{
  OIFS=$IFS
  IFS='/'
  local NORMALIZED=

  for I in $1
  do
    # Resolve relative path punctuation.
    if [ "$I" = "." ] || [ -z "$I" ]
      then continue

    elif [ "$I" = ".." ]
      then
        NORMALIZED=$(echo "$NORMALIZED"|sed 's/\/[^/]*$//g')
        # FIXME: normalize with special chars
        #NORMALIZED=$(echo "$NORMALIZED"|sed 's/\/\"\?[^/]*\?$//g')
        continue
      else
        NORMALIZED="${NORMALIZED}/${I}"
        #test -n "$NORMALIZED" \
        #  && NORMALIZED="${NORMALIZED}/${I}" \
        #  || NORMALIZED="${I}"
    fi
  done
  IFS=$OIFS
  test -n "$NORMALIZED" \
    && {
      case "$1" in
        /* ) ;;
        * )
            NORMALIZED="$(expr_substr "$NORMALIZED" 2 ${#NORMALIZED} )"
          ;;
      esac
    } || NORMALIZED=.
  trueish "${strip_trail-}" && echo "$NORMALIZED" || case "$1" in
    */ ) echo "$NORMALIZED/"
      ;;
    * ) echo "$NORMALIZED"
      ;;
  esac
}

# FIXME: can Bourne Sh do pushd/popd in a function?
#cmd_exists pushd || {
#pushd()
#{
#  tmp=/tmp/pushd-$$
#  echo "pushd \$\$=$$ $@"
#  echo "$1" >>$tmp
#  cd $1
#}
#popd()
#{
#  tmp=/tmp/pushd-$$
#  echo "popd \$\$=$$ $@"
#  tail -n 1 $tmp
#  cd $(truncate_trailing_lines $tmp 1)
#}
#}
#
#pushd_cwdir()
#{
#  test -n "$CWDIR" -a "$CWDIR" != "$PWD" && {
#    echo "pushd $CWDIR" "$PWD"
#    pushd $WDIR
#  } || set --
#}
#
#popd_cwdir()
#{
#  test -n "$CWDIR" -a "$CWDIR" = "$PWD" && {
#    echo "popd $CWDIR" "$PWD"
#    test "$(popd)" = "$CWDIR"
#  } || set --
#}

read_addcol ()
{
  test -n "${act-}" || local act="echo"
  while ${read:-read -r} S
    do printf -- '%s\t%s\n' "$S" "$($act "$S")" ; done
}

# XXX: rename read-literal
read_asis ()
{
  IFS= read -r "$@"
}

# Prefix/suffix lines with fixed value string
read_concat () # ~ [<Prefix-str>] [<Suffix-str>] # Concat value to lines
{
  local _S
  while ${read:-read -r} _S
  do echo "${1:-}${_S}${2:-}"; done
}

# XXX:
#read_concat_col ()
#{
#  test -n "${p-}" || local p= # Prefix string
#  test -n "${s-}" || local s= # Suffix string
#  while ${read:-read -r} _S
#    do echo "$p$_S$s"; done
#}

# Read only data, trimming whitespace but leaving '\' as-is.
# See read-escaped and read-literal for other modes/impl.
read_data () # (s) ~ <Read-argv...> # Read into variables, ignoring escapes and collapsing whitespacek
{
  read -r "$@"
}

# Read character data separated by spaces, allowing '\' to escape special chars.
# See also read-literal and read-content.
read_escaped ()
{
  #shellcheck disable=2162 # Escaping can be useful to ignore line-ends, and read continuations as one line
  read "$@"
}

# Test for file or return before read
read_if_exists ()
{
  test -n "${1-}" || return 1
  read_nix_style_file "$@" 2>/dev/null || return 1
}

# [0|1] [line_number=] read-lines-while FILE WHILE [START] [END]
#
# Read FILE lines and set line_number while WHILE evaluates true. No output,
# WHILE should evaluate silently, see lines-while. This routine sets up a
# (subshell) pipeline from lines-slice START END to lines-while, and captures
# only the status and var line-number from the subshel.
#
read_lines_while() # File-Path While-Eval [First-Line] [Last-Line]
{
  test -n "${1-}" || error "Argument expected (1)" 1
  test -f "$1" || error "Not a filename argument: '$1'" 1
  test -n "${2-}" -a $# -le 4 || return
  local stat=''

  read_lines_while_inner() # sh:no-stat
  {
    local r=0
    lines_slice "${3-}" "${4-}" "$1" | {
        lines_count_while_eval "$2" || r=$? ; echo "$r $line_number"; }
  }
  stat="$(read_lines_while_inner "$@")"
  test -n "$stat" || return
  line_number=$(echo "$stat" | cut -f2 -d' ')
  return "$(echo "$stat" | cut -f1 -d' ')"
}

# [0|1] [line_number=] read-lines-while FILE WHILE [START] [END]
#
# Read FILE lines and set line_number while WHILE evaluates true. No output,
# WHILE should evaluate silently, see lines-while. This routine sets up a
# (subshell) pipeline from lines-slice START END to lines-while, and captures
# only the status and var line-number from the subshel.
#
read_lines_while() # File-Path While-Eval [First-Line] [Last-Line]
{
  test -n "${1-}" || error "Argument expected (1)" 1
  test -f "$1" || error "Not a filename argument: '$1'" 1
  test -n "${2-}" -a $# -le 4 || return
  local stat=''

  read_lines_while_inner()
  {
    local r=0
    lines_slice "${3-}" "${4-}" "$1" | {
        lines_count_while_eval "$2" || r=$? ; echo "$r $line_number"; }
  }
  stat="$(read_lines_while_inner "$@")"
  test -n "$stat" || return
  line_number=$(echo "$stat" | cut -f2 -d' ')
  return "$(echo "$stat" | cut -f1 -d' ')"
}

# Read file filtering octothorp comments, like this one, and empty lines
# XXX: this one support leading whitespace but others in ~/bin/*.sh do not
read_nix_style_file () # [cat_f=] ~ File [Grep-Filter]
{
  test $# -le 2 -a "${1:-"-"}" = - -o -e "${1-}" || return 98
  test -n "${1-}" || set -- "-" "${2-}"
  test -n "${2-}" || set -- "$1" '^\s*(#.*|\s*)$'
  test -z "${cat_f-}" && {
    grep -Ev "$2" "$1" || return $?
  } || {
    cat $cat_f "$1" | grep -Ev "$2"
  }
}

# Read pairs and rsync. Env dry-run=0 to execute, rsync-a to override 'vaL' flags.
rsync_pairs()
{
  test -n "$rsync_a" || rsync_a=-vaL
  falseish "$dry_run" || rsync_a=${rsync_a}n

  while read -r src dest
  do
    mkdir -p "$(dirname "$dest")"
    rsync $rsync_a "$src" "$dest" && {
        falseish "$dry_run" &&
        note "Synced <$src> to <$dest>" ||
        note "**dry run ** Synced <$src> to <$dest>"
    } || {
        error "Syncing <$src> to <$dest>"
        return 1
    }
  done
}

sameas ()
{
  test -f "$1" -a -f "$2" || error "sameas: two file name expected: $*" 1
  test $(stat -f "%i" "$1") -eq $(stat -f "%i" "$2")
}

shortdir () # ~ [<Dir>] # Wrapper to print short dir with Python
{
  test -n "$1" || set -- "$PWD"
  # XXX maybe replace python script. Only replaces home
  $HOME/bin/short-pwd.py -1 "$1"
}

# Sort paths by mtime. Uses foreach-addcol to add mtime column, sort on and then
# remove again. Listing most-recent modified file name/path first.
sort_mtimes ()
{
  act=filemtime foreach_addcol "$@" | sort -r -k 2 | cut -f 1
}

# Read single multipath to one path per line
split_multipath()
{
  local root=
  { test -n "${1-}" && echo "$@" || cat - ; } \
     | grep -Ev '^(#.*|\s*)$' \
     | sed 's/\([^\.]\)\/\.\./\1\
../g' \
     | grep -v '^\.[\.\/]*$' \
     | while read -r rel_leaf
  do
    echo $rel_leaf | grep -q '^\.\.\/' && {
      normalize $root/$rel_leaf
    } || {
      root=$rel_leaf
      normalize $rel_leaf
    }
  done
  test -n "$root" || error "No root found" 1
}

# strip-trailing-dash
strip_trail()
{
  fnmatch "*/" "$1" && {
    echo "$1" | sed 's/\/$//'
  } ||
    echo "$1"
}

# Sum column and add total-line after stdin closes.
sumcolumn () # (s) ~ <ColNr> [<Prefix>] [<Awk-Line-expr>]
{
  awk '{ sum += $'"${1:?"A column number is required"}"'; '"${3-"print "}"'}
      END { print "'"${2-"Total: "}"'"sum; }'
}

symlink_assert () # <Symlink-Path> <Target>
{
  test -d "$1" -a ! -h "$1" &&
      set -- "$1" "$2" "$1/$(basename -- "$2")" || set -- "$1" "$2" "$1"
  test -h "$3" && {
    local target="$(readlink "$3")"
    test "$target" = "$2" && return
    rm "$3"
  }
  local v=; test $verbosity -lt 7 || v=v
  ln -s$v "$2" "$3"
}

# Tell where a file is from (using extended attributes)
wherefrom ()
{
  # XXX: this sould fail if no os given, TODO: look at lib-{load,req} specs
  lib_load ${os:="$(str_lower "${uname:-"$(uname -s)"}")"} || return
  ${os,,}_wherefrom "$@"
}

# Because 'act=... foreach_do' doesn't read that nice.
# No eval, no spaces/quoting in command-argv.
xargs_fun () # (s) ~ <Command <Argv...>> # Suffix lines to argv and run
{
  act="$*" foreach_do -
}

# BSD helper
xsed_rewrite () # ~ <Sed-argv...>
{
  case "${uname:?}" in
    Darwin ) sed -i.applyBack "$@";;
    Linux ) sed -i "$@";;
    * ) return 60 ;;
  esac
}

# Sync: U-S:src/sh/lib/os.lib.sh
