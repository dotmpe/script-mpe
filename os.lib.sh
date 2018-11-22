#!/bin/sh


# OS: files, paths

os_lib_load()
{
  test -n "$uname" || uname="$(uname -s)"
  test -n "$os" || os="$(uname -s | tr '[:upper:]' '[:lower:]')"

  test -n "$gsed" || case "$uname" in
      Linux ) gsed=sed ;; * ) gsed=gsed ;;
  esac
  test -n "$ggrep" || case "$uname" in
      Linux ) ggrep=grep ;; * ) ggrep=ggrep ;;
  esac
}


absdir()
{
  # NOTE: somehow my Linux pwd makes a symbolic path to root into //bin,
  # using tr to collapse all sequences to one
  ( cd "$1" && pwd -P | tr -s '/' '/' )
}

dirname_()
{
  while test $1 -gt 0
    do
      set -- $(( $1 - 1 ))
      set -- "$1" "$(dirname "$2")"
    done
  echo "$2"
}

# Combined dirname/basename to remove .ext(s) but return path
pathname() # PATH EXT...
{
  local name="$1" dirname="$(dirname "$1")"
  fnmatch "./*" "$1" && dirname="$(echo "$dirname" | cut -c3-)"
  shift 1
  for ext in $@
  do
    name="$(basename "$name" "$ext")"
  done
  test -n "$dirname" -a "$dirname" != "." && {
    printf -- "$dirname/$name\\n"
  } || {
    printf -- "$name\\n"
  }
}
# basepath: see pathname as alt. to basename for ext stripping

# Simple iterator over pathname
pathnames() # exts=... [ - | PATHS ]
{
  test -n "$exts" || exit 40
  test -n "$*" -a "$1" != "-" && {
    for path in "$@"
    do
      pathname "$path" $exts
    done
  } || {
    { cat - | while read -r path
      do pathname "$path" $exts
      done
    }
  }
}

realpaths()
{
  act=realpath p= s= foreach_do "$@"
}

# Cumulative dirname, return the root directory of the path
basedir()
{
  # Recursively. FIXME: a string op. may be faster
  while fnmatch "*/*" "$1"
  do
    set -- "$(dirname "$1")"
    test "$1" != "/" || break
  done
  echo "$1"
}

dotname() # Path [Ext-to-Strip]
{
  echo $(dirname "$1")/.$(basename "$1" "$2")
}

short()
{
  test -n "$1" || set -- "$(pwd)"
  # XXX maybe replace python script. Only replaces home
  $scriptpath/short-pwd.py -1 "$1"
}

# [exts=] basenames [ .EXTS ] PATH...
# Get basename(s) for all given exts of each path. The first argument is handled
# dynamically. Unless exts env is provided, if first argument is not an existing
# and starts with a period '.' it is used as the value for exts.
basenames()
{
  test -n "$exts" || {
    test -e "$1" || fnmatch ".*" "$1" && { exts="$1"; shift; }
  }
  while test -n "$1"
  do
    name="$1"
    shift
    for ext in $exts
    do
      name="$(basename "$name" "$ext")"
    done
    echo "$name"
  done
}

# for each argument echo filename-extension suffix (last non-dot name element)
filenamext() # Name..
{
  while test -n "$1"; do
    basename "$1"
  shift; done | grep '\.' | sed 's/^.*\.\([^\.]*\)$/\1/'
}

# Return basename for one file, using filenamext to extract extension.
# See basenames for multiple args, and pathname to preserve (relative) directory
# elements for name.
filestripext() # Name
{
  ext="$(filenamext "$1")"
  basename "$1" ".$ext"
}

# Check wether name has extension, return 0 or 1
fileisext() # Name Exts..
{
  local f="$1" ext="" ; ext=$(filenamext "$1") || return ; shift
  test -n "$*" || return
  test -n "$ext" || return
  for mext in $@
  do test ".$ext" = "$mext" && return 0
  done
  return 1
}

filename_baseid()
{
  basename="$(filestripext "$1")"
  mkid "$basename" '' '_-'
}

# Use `file` to get mediatype aka. MIME-type
filemtype() # File..
{
  local flags= ; file_tool_flags
  case "$uname" in
    Darwin )
        file -${flags}I "$1" || return 1
      ;;
    Linux )
        file -${flags}i "$1" || return 1
      ;;
    * ) error "filemtype: $uname?" 1 ;;
  esac
}

# Description of file contents, format
fileformat()
{
  local flags= ; file_tool_flags
  case "$uname" in
    Darwin | Linux )
        file -${flags} "$1" || return 1
      ;;
    * ) error "fileformat: $uname?" 1 ;;
  esac
}

# Use `stat` to get size in bytes
filesize() # File
{
  local flags=- ; file_stat_flags
  case "$uname" in
    Darwin )
        stat -f '%z' $flags "$1" || return 1
      ;;
    Linux )
        stat -c '%s' $flags "$1" || return 1
      ;;
    * ) error "filesize: $1?" 1 ;;
  esac
}

# Use `stat` to get modification time (in epoch seconds)
filemtime() # File
{
  local flags=- ; file_stat_flags
  case "$uname" in
    Darwin )
        trueish "$file_names" && pat='%N %m' || pat='%m'
        stat -f "$pat" $flags "$1" || return 1
      ;;
    Linux )
        trueish "$file_names" && pat='%N %Y' || pat='%Y'
        stat -c "$pat" $flags "$1" || return 1
      ;;
    * ) error "filemtime: $1?" 1 ;;
  esac
}

# Use `stat` to get birth time (in epoch seconds)
filebtime() # File
{
  local flags=- ; file_stat_flags
  case "$uname" in
    Darwin )
        trueish "$file_names" && pat='%N %B' || pat='%B'
        stat -f "$pat" $flags "$1" || return 1
      ;;
    Linux )
        # XXX: %N is deref-file
        trueish "$file_names" && pat='%N %W' || pat='%W'
        stat -c "$pat" $flags "$1" || return 1
      ;;
    * ) error "filebtime: $1?" 1 ;;
  esac
}


file_tool_flags()
{
  trueish "$file_names" && flags= || flags=b
  falseish "$file_deref" || flags=${flags}L
}

# FIXME: file-deref=0?
file_stat_flags()
{
  test -n "$flags" || flags=-
  falseish "$file_deref" || flags=${flags}L
  test "$flags" != "-" || flags=
}


# Split expression type from argument and set envs expr_/type_
foreach_match_setexpr() # [Type:]Expression
{
  test -n "$1" || set -- '*'
  expr_="$1"
  fnmatch "*:*" "$expr_" && {
    type_="$(echo "$expr_" | cut -c1)"
    expr_="$(echo "$expr_" | sed 's/^[^:]*://')"
  } || {
    type_=g
  }
  info "Mode: $type_, Expression: '$expr_'"
}

# Execute act/no-act based on expression match, function/command or shell statement
# Types are [g]lob-match, grep-[r]egex, local-cmd e[x]pression or [e]val expression.
# Subjects (stdin lines) may be provided as arguments instead, and to do
# additional prefix/suffix addition on subjects (and only there).
foreach_match() # [type_=(grxe) expr_= act=echo no_act=/dev/null p= s=] [Subject...]
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


# Go over arguments and echo. If no arguments given, or on argument '-' the
# standard input is cat instead or in-place respectively. Strips empty lines.
# (Does not open filenames and read from files. Except cat for stdin. See
# lines-while.)
foreach()
{
  {
    test -n "$*" && {
      while test $# -gt 0
      do
        test "$1" = "-" && {
          cat -
        } || {
          printf -- '%s\n' "$1"
        }
        shift
      done
    } || cat -
  } | grep -v '^$'
}

# Read `foreach` lines and act, default is echo ie. same result as `foreach`
foreach_do()
{
  test -n "$act" || act="echo"
  foreach "$@" | while read -r _S ; do S="$p$_S$s" && $act "$S" ; done
}

# Extend rows by mapping each value line using act, add result tab-separated to line
foreach_addcol()
{
  test -n "$act" || act="echo"
  foreach "$@" | while read -r _S
    do S="$p$_S$s" && printf -- '%s\t%s\n' "$S" "$($act "$S")" ; done
}

foreach_inscol()
{
  test -n "$act" || act="echo"
  foreach "$@" | while read -r _S
    do S="$p$_S$s" && printf -- '%s\t%s\n' "$($act "$S")" "$S" ; done
}

# Add column to sort paths at mtimes, then remove mtime column listing
# most-recent modified file first.
sort_mtimes()
{
  p= s= act=filemtime foreach_addcol "$@" | sort -r -k 2 | cut -f 1
}


normalize_relative()
{
  OIFS=$IFS
  IFS='/'
  local NORMALIZED

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
  trueish "$strip_trail" && echo "$NORMALIZED" || case "$1" in
    */ ) echo "$NORMALIZED/"
      ;;
    * ) echo "$NORMALIZED"
      ;;
  esac
}


# Read single multipath to one path per line
split_multipath()
{
  local root=
  { test -n "$1" && echo "$@" || cat - ; } \
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

# Read file filtering octothorp comments, like this one, and empty lines
# XXX: this one support leading whitespace but others in ~/bin/*.sh do not
read_nix_style_file() # [cat_f=] ~ File [Grep-Filter]
{
  test -n "$1" || return 1
  test -n "$2" || set -- "$1" '^\s*(#.*|\s*)$'
  test -z "$3" || error "read-nix-style-file: surplus arguments '$2'" 1
  cat $cat_f "$1" | grep -Ev "$2" || return 1
}

grep_nix_lines()
{
  grep -Ev '^\s*(#.*|\s*)$' "$@"
}

# Number lines from read-nix-style-file by src, filter comments after.
enum_nix_style_file()
{
  cat_f=-n read_nix_style_file "$@" '^[0-9]*:\s*(#.*|\s*)$' || return
}

# Test for file or return before read
read_if_exists()
{
  test -n "$1" || return 1
  read_nix_style_file "$@" 2>/dev/null || return 1
}

# Read $line as long as CMD evaluates, and increment $line_number.
# CMD can be silent or verbose in anyway, but when it fails the read-loop
# is broken.
lines_while() # CMD
{
  test -n "$1" || return

  line_number=0
  while read -r line
  do
    eval $1 || break
    line_number=$(( $line_number + 1 ))
  done
  test $line_number -gt 0 || return
}

# Offset content from input/file to line-based window.
lines_slice() # [First-Line] [Last-Line] [-|File-Path]
{
  test -n "$3" || error "File-Path expected" 1
  test "$3" = "-" && set -- "$1" "$2"
  test -n "$1" && {
    test -n "$2" && { # Start - End: tail + head
      tail -n "+$1" "$3" | head -n $(( $2 - $1 + 1 ))
    } || { # Start - ... : tail
      tail -n "+$1" "$3"
    }

  } || {
    test -n "$2" && { # ... - End : head
      head -n "$2" "$3"
    } || { # Otherwise cat
      cat "$3"
    }
  }
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
  test -n "$1" || error "Argument expected (1)" 1
  test -f "$1" || error "Not a filename argument: '$1'" 1
  test -n "$2" -a -z "$5" || return
  local stat=''

  read_lines_while_inner()
  {
    local r=0
    lines_slice "$3" "$4" "$1" | {
        lines_while "$2" || r=$? ; echo "$r $line_number"; }
  }
  stat="$(read_lines_while_inner "$@")"
  test -n "$stat" || return
  line_number=$(echo "$stat" | cut -f2 -d' ')
  return "$(echo "$stat" | cut -f1 -d' ')"
}


# Change cwd to parent dir with existing local path element (dir/file/..) $1, leave go_to_before var in env.
go_to_dir_with()
{
  test -n "$1" || error "go-to-dir: Missing filename arg" 1

  # Find dir with metafile
  go_to_before=.
  while true
  do
    test -e "$1" && break
    go_to_before=$(basename "$(pwd)")/$go_to_before
    test "$(pwd)" = "/" && break
    cd ..
  done

  test -e "$1" || return 1
}


# Go to dir and set OLDPWD, but only if not already there
#go_to_dir()
#{
#  test -n "$1" || set -- "."
#  test "$1" = "." || cd "$1"
#  # -o "$(pwd -P)" = "$(cd "$1" && pwd -P)" || cd $1
#}


# Resolve all symlinks in subtree, return a list with targets
get_targets()
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

count_lines()
{
  test -z "$1" -o "$1" = "-" && {
    wc -l | awk '{print $1}'
  } || {
    while test -n "$1"
    do
      wc -l $1 | awk '{print $1}'
      shift
    done
  }
}

# Wrap wc but correct files with or w.o. trailing posix line-end
line_count()
{
  test -s "$1" || return 42
  test $(filesize "$1") -gt 0 || return 43
  lc="$(echo $(od -An -tc -j $(( $(filesize $1) - 1 )) $1))"
  case "$lc" in "\n" ) ;;
    "\r" ) error "POSIX line-end required" 1 ;;
    * ) printf '\n' >>$1 ;;
  esac
  local lc=$(wc -l $1 | awk '{print $1}')
  echo $lc
}

# Count words
count_words()
{
  test -z "$1" -o "$1" = "-" && {
    wc -w | awk '{print $1}'
  } || {
    while test -n "$1"
    do
      wc -w $1 | awk '{print $1}'
      shift
    done
  }
}

# Count every character
count_chars()
{
  test -n "$1" && {
    while test -n "$1"
    do
      wc -c $1 | awk '{print $1}'
      shift
    done
  } || {
    wc -w | awk '{print $1}'
  }
}

# Count occurence of character each line
count_char() # Char
{
  local ch="$1" ; shift
  awk -F$ch '{print NF-1}' |
      # strip -1 "error" for empty line
      sed 's/^-1$//'
}

# Count tab-separated columns on first line. One line for each file.
count_cols()
{
  test -n "$1" && {
    while test -n "$1"
    do
      { printf '\t'; head -n 1 "$1"; } | count_char '\t'
      shift
    done
  } || {
    { printf '\t'; head -n 1; } | count_char '\t'
  }
}

xsed_rewrite()
{
  case "$uname" in
    Darwin ) sed -i.applyBack "$@";;
    Linux ) sed -i "$@";;
  esac
}

get_uuid()
{
  test -e /proc/sys/kernel/random/uuid && {
    cat /proc/sys/kernel/random/uuid
    return 0
  }
  test -x $(which uuidgen) && {
    uuidgen
    return 0
  }
  error "FIXME uuid required" 1
  return 1
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
#  test -n "$CWDIR" -a "$CWDIR" != "$(pwd)" && {
#    echo "pushd $CWDIR" "$(pwd)"
#    pushd $WDIR
#  } || set --
#}
#
#popd_cwdir()
#{
#  test -n "$CWDIR" -a "$CWDIR" = "$(pwd)" && {
#    echo "popd $CWDIR" "$(pwd)"
#    test "$(popd)" = "$CWDIR"
#  } || set --
#}

# strip-trailing-dash
strip_trail()
{
  fnmatch "*/" "$1" && {
    echo "$1" | sed 's/\/$//'
  } ||
    echo "$1"
}

# if not exists, create directories and touch file for each given path arg
assert_files()
{
  for fn in $@
  do
    test -n "$fn" || continue
    test -e $fn || {
      test -z "$(dirname $fn)" || mkdir -vp $(dirname $fn)
      touch $fn
    }
  done
}

lock_files()
{
  local id=$1
  shift
  info "Reserving resources for session $id ($*)"
  for f in $@
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

unlock_files()
{
  local id=$1 lock=
  shift
  info "Releasing resources from session $id ($*)"
  for f in $@
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

verify_lock()
{
  local id=$1
  shift
  for f in $@
  do
    test -e "$f.lock" || return 2
    test "$(head -n 1 $f.lock | awk '{print $1}')" = "$id" || return 1
  done
}


mkrlink()
{
  # TODO: find shortest relative path
  ln -vs "$(basename "$1")" "$2"
}

filter_dirs()
{
  test "$1" = "-" && {
    while read -r d
    do
      test -d "$d" || continue
      echo "$d"
    done
  } || {
    for d in "$@"
    do
      test -d "$d" || continue
      echo "$d"
    done
  }
}

filter_files()
{
  test "$1" = "-" && {
    while read -r f
    do
      test -f "$f" || continue
      echo "$f"
    done
  } || {
    for f in "$@"
    do
      test -f "$f" || continue
      echo "$f"
    done
  }
}

disk_usage()
{
  test -n "$1" || set -- "." "$2"
  test -n "$2" || set -- "$1" "h"
  du -$2s $1 | awk '{print $1}'
}

isemptydir()
{
  test -d "$1" -a "$(echo $1/*)" = "$1/*"
}

isnonemptydir()
{
  test -d "$1" -a "$(echo $1/*)" != "$1/*"
}

find_one()
{
  find_num "$@"
}

find_num()
{
  test -n "$1" -a -n "$2" || error "find-num '$*'" 1
  test -n "$3" || set -- "$@" 1
  local c=0
  find "$1" -iname "$2" | while read -r path
  do
    c=$(( $c + 1 ))
    test $c -le $3 || return 1
    echo "$path"
  done
}

find_broken_symlinks()
{
  test -n "$1" || set -- .
  #test "$uname" = "Darwin" && find=gfind
  #$find "$1" -type l -xtype l || return $?
  find "$1" -type l ! -exec test -e {} \; -print
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

# Add number to file, provide extension to split basename before adding suffix
number_file() # [action=mv] Name [Ext]
{
  local dir=$(dirname "$1") cnt=1 base=$(basename "$1")

  while test -e "$dir/$base-$cnt$2"
  do
    cnt=$(( $cnt + 1 ))
  done
  dest=$dir/$base-$cnt$2

  test -n "$action" || action="mv"
  { $action -v "$1" "$dest" || return $?; } | abbrev_rename
}

# make numbered copy, see number-file
backup_file() # [action=mv] Name [Ext]
{
  action="cp" number_file "$1"
}

# rename to numbered file, see number-file
rotate_file() # [action=mv] Name [Ext]
{
  test -s "$1" || return
  action="mv" number_file "$1"
}

wherefrom()
{
  ${os}_wherefrom "$@"
}

sameas()
{
  test -f "$1" -a -f "$2" || error "sameas: two file name expected: $*" 1
  test $(stat -f "%i" "$1") -eq $(stat -f "%i" "$2")
}

filesizesum()
{
  sum=0
  while read -r file
  do
      sum=$(( $sum + $(filesize "$file" | tr -d '\n' ) ))
  done
  echo $sum
}


# XXX: turn lists into columns, using shell vars but does that scale?
ziplists() # [SEP=\t] Rows
{
  local col=0 row=0
  test -n "$SEP" || SEP='\t'
  while true
  do
    col=$(( $col + 1 )) ;
    for row in $(seq 1 $1) ; do
      read -r row${row}_col${col} || break 2
    done
  done
  col=$(( $col - 1 ))

  for r in $(seq 1 $1)
  do
    for c in $(seq 1 $col)
    do
      eval printf \"%s\" \"\$row${r}_col${c}\"
      test $c -lt $col && printf "$SEP" || printf '\n'
    done
  done
}

# Ziplists on lines from files. XXX: Each file should be same length.
zipfiles()
{
  rows="$(count_lines "$1")"
  { for file in "$@" ; do
      cat "$file"
      #truncate_lines "$file" "$rows"
    done
  } | ziplists $rows
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

linux_uptime()
{
  cut -d' ' -f1 /proc/uptime
}

linux_boottime()
{
  echo $(( $($gdate +"%s" ) + $(linux_uptime) ))
}

# Remove duplicate lines (unlike uniq -u) without sorting
remove_dupes()
{
  awk '!a[$0]++' "$@"
}
