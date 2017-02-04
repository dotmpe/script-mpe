#!/bin/sh


# OS: files, paths

# Combined dirname/basename to replace .ext
basepath()
{
	echo "$(dirname "$1")/$(basename "$1" "$2")$3"
}

short()
{
  test -n "$1" || set -- "$(pwd)"
  # XXX maybe replace python script sometime
  $scriptdir/short-pwd.py -1 "$1"
}

# Get basename for each path: [ .EXT ] PATHS...
basenames()
{
  local ext=
  test -e "$1" || fnmatch ".*" "$1" && { ext=$1; shift; }
  while test -n "$1"
  do
    basename "$1" "$ext"
    shift
  done
}

filesize()
{
  case "$uname" in
    Darwin )
      stat -L -f '%z' "$1" || return 1
      ;;
    Linux )
      stat -L -c '%s' "$1" || return 1
      ;;
  esac
}

filemtime()
{
  case "$uname" in
    Darwin )
      stat -L -f '%m' "$1" || return 1
      ;;
    Linux )
      stat -L -c '%Y' "$1" || return 1
      ;;
  esac
}


#
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
  cat $@ | grep -Ev '^\s*(#.*|\s*)$' || return 1
}

read_if_exists()
{
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


# Change cwd to parent dir with file $1, leave go_to_before var in env.
go_to_directory()
{
  test -n "$1" || error "Missing filename arg" 1

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
  test -n "$1" && {
    while test -n "$1"
    do
      wc -l $1 | awk '{print $1}'
      shift
    done
  } || {
    wc -l | awk '{print $1}'
  }
}

count_words()
{
  test -n "$1" && {
    while test -n "$1"
    do
      wc -w $1 | awk '{print $1}'
      shift
    done
  } || {
    wc -w | awk '{print $1}'
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
  test $(filesize $1) -gt 0 || return 43
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
        Linux ) sed "$@";;
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

test_dir()
{
	test -d "$1" || {
		err "No such dir: $1"
		return 1
	}
}

test_file()
{
	test -f "$1" || {
		err "No such file: $1"
		return 1
	}
}

# strip-trailing-dash
strip_trail()
{
  fnmatch "*/" "$1" && {
    echo "$1" | sed 's/\/$//'
  } ||
    echo "$1"
}

