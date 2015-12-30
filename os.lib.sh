#!/bin/sh

test -n "$PREFIX" || PREFIX=$HOME


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
#        echo "a I='$I' NORMALIZED='$NORMALIZED'"
        test "${NORMALIZED%%/${NORMALIZED##*/}}" != "$NORMALIZED" \
          && NORMALIZED="${NORMALIZED%%/${NORMALIZED##*/}}" \
          || NORMALIZED=
#        echo "b I='$I' NORMALIZED='$NORMALIZED'"
        continue
      else
#        echo "c I='$I' NORMALIZED='$NORMALIZED'"
        test -n "$NORMALIZED" \
          && NORMALIZED="${NORMALIZED}/${I}" \
          || NORMALIZED="${I}"
#        echo "d I='$I' NORMALIZED='$NORMALIZED'"
    fi

#    echo "end I=$I NORMALIZED='$NORMALIZED'"

    # Dereference symbolic links.
    if [ -h "$NORMALIZED" ] && [ -x "/bin/ls" ]
      then IFS=$OIFS
           set `/bin/ls -l "$NORMALIZED"`
           echo "@=$@"
           while shift ;
           do
             if [ "$1" = "->" ]
               then NORMALIZED="$2"
                    shift $#
                    break
             fi
           done
    fi

  done
  IFS=$OIFS
  test "${1#/}" = "$1" \
    && echo "$NORMALIZED" \
    || echo "/$NORMALIZED"
  unset NORMALIZED
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

