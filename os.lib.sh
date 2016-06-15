#!/bin/sh


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
            NORMALIZED=$(expr_substr $NORMALIZED 2 ${#NORMALIZED} )
          ;;
      esac
    } || NORMALIZED=.
  case "$1" in
    */ ) echo $NORMALIZED/
      ;;
    * ) echo $NORMALIZED
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
  cat $1 | grep -Ev '^\s*(#.*|\s*)$'
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
  local ln_f=/tmp/script-os-lib-sh-$(uuidgen)
  test ! -e $ln_f
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


# Traverse to parent dir with file
go_to_directory()
{
  test -n "$doc" || doc=$1

  # Find dir with metafile
  go_to_before=.
  while true
  do
    test -e "$doc" && break
    go_to_before=$(basename $(pwd))/$go_to_before
    test "$(pwd)" = "/" && break
    cd ..
  done

  test -e "$doc" || return 1
}

# Resolve all symlinks in subtree, return a list with targets
get_targets()
{
  test -n "$1" || set -- /srv
  # Assume
  find $1 -type l | while read link
  do
    target=$(readlink $link)
    normalize_relative $(dirname $link)/$target
  done | sort -u
}

