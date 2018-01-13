#!/bin/sh


# OS: files, paths

os_lib_load()
{
  test -n "$uname" || export uname="$(uname -s)"
}

absdir()
{
  # NOTE: somehow my Linux pwd makes a symbolic path to root into //bin.
  ( cd "$1" && pwd -P | tr -s '/' '/' )
}

# Combined dirname/basename to replace .ext(s)
# pathname PATH EXT...
pathname()
{
  local name="$1" dirname="$(dirname "$1")"
  shift 1
  for ext in $@
  do
    name="./$(basename "$name" "$ext")"
  done
  test -n "$dirname" -a "$dirname" != "." && {
    printf -- "$dirname/$name\n"
  } || {
    printf -- "$name\n"
  }
}
# basepath: see pathname as alt. to basename for ext stripping

pathnames()
{
  test -n "$exts" || exit 40
  test -n "$*" && {
    for path in "$@"
    do
      pathname "$path" $exts
    done
  } || {
    { cat - | while read path
      do pathname "$path" $exts
      done
    }
  }
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
}

dotname()
{
  echo $(dirname "$1")/.$(basename "$1")
}

short()
{
  test -n "$1" || set -- "$(pwd)"
  # XXX maybe replace python script sometime
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

filenamext() # for each argument, echo just the filename-extension suffix
{
  while test -n "$1"; do
    echo "$1" | sed 's/^.*\.\([^\.]*\)$/\1/'
  shift; done
}

filestripext()
{
  basename "$1" ".$(filenamext "$1")"
}

fileisext()
{
  local f="$1" ext=$(filenamext "$1"); shift
  test -n "$*" || return
  test -n "$ext" || return
  for mext in $@
  do test ".$ext" = "$mext" && return 0
  done
  return 1
}

filemtype()
{
  while test $# -gt 0
  do
    case "$uname" in
      Darwin )
          file -bI "$1" || return 1
        ;;
      Linux )
          file -bi "$1" || return 1
        ;;
      * ) error "filemtype: $uname?" 1 ;;
    esac; shift
  done
}

filesize()
{
  while test $# -gt 0
  do
    case "$uname" in
      Darwin )
          stat -L -f '%z' "$1" || return 1
        ;;
      Linux )
          stat -L -c '%s' "$1" || return 1
        ;;
      * ) error "filesize: $1?" 1 ;;
    esac; shift
  done
}

filemtime()
{
  while test $# -gt 0
  do
    case "$uname" in
      Darwin )
          stat -L -f '%m' "$1" || return 1
        ;;
      Linux )
          stat -L -c '%Y' "$1" || return 1
        ;;
      * ) error "filemtime: $1?" 1 ;;
    esac; shift
  done
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
     | while read rel_leaf
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

# Read file filtering octotorphe comments, like this one and empty lines
# XXX: this one support leading whitespace but others in ~/bin/*.sh do not
read_nix_style_file()
{
  test -n "$1" || return 1
  test -z "$2" || error "read-nix-style-file: surplus arguments '$2'" 1
  cat $cat_f "$1" | grep -Ev '^\s*(#.*|\s*)$' || return 1
}

# Number lines from read-nix-style-file
enum_nix_style_file()
{
  cat_f=-n read_nix_style_file "$@" || return
}

read_if_exists()
{
  test -n "$1" || return 1
  read_nix_style_file $@ 2>/dev/null || return 1
}

# [0|1] [1] read-file-lines-while file-path [while-expr]
# Read lines in file while second argument evaluates (ie. w/o exiting non-zero)
# Echo's each line, and count lines in line_number global var. Expression
# while-expr is run within a `while read line` loop, and can refer to '$line'
# and/or '$line_number' (and to '$1' also..).
# Default while-expr is to read only empty commented lines.
# Return non-zero if no match was found.
read_file_lines_while()
{
  test -n "$1" || error "Argument expected (1)" 1
  test -f "$1" || error "Not a filename argument: '$1'" 1
  test -n "$2" || set -- "$1" 'echo "$line" | grep -qE "^\s*(#.*|\s*)$"'
  line_number=0
  local ln_f="$(setup_tmpf)"

  test -n "$ln_f" -a ! -e "$ln_f"

  cat $1 | while read line
  do
    line_number=$(( $line_number + 1 ))
    eval $2 || { echo $(( line_number - 1 ))>$ln_f; return; }
    echo $line
  done
  test -s "$ln_f" \
    && export line_number=$(cat $ln_f) \
    || unset line_number
  rm $ln_f 2>/dev/null || return $?
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


go_to_dir()
{
  test -n "$1" || set -- "."
  test "$1" = "." || cd "$1"
  # -o "$(pwd -P)" = "$(cd "$1" && pwd -P)" || cd $1
}


# Resolve all symlinks in subtree, return a list with targets
get_targets()
{
  test -n "$1" || set -- /srv
  # Assume
  find $1 -type l | while read link
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

# Wrap wc but correct files with or w.o. trailing posix line-end
line_count()
{
  test -s "$1" || return 42
  test $(filesize "$1") -gt 0 || return 43
  lc="$(echo $(od -An -tc -j $(( $(filesize $1) - 1 )) $1))"
  case "$lc" in "\n" ) ;;
    "\r" ) error "POSIX line-end required" 1 ;;
    * ) printf "\n" >>$1 ;;
  esac
  local lc=$(wc -l $1 | awk '{print $1}')
  echo $lc
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
    while read d
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
    while read f
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
  find "$1" -iname "$2" | while read path
  do
      c=$(( $c + 1 ))
      test $c -le $3 || return 1
      echo "$path"
  done
}
