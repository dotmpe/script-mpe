#!/bin/sh

set -e


sd_be_name=fsdir

fsdir()
{
  local p=$sd_tmp_dir/fsdir k="$2" tlt="$3" v="$4"
  test -d $p || mkdir $p
  case "$1" in

    get )
        test -e "$p/$2" && echo "$(cat "$p/$2")" || return
      ;;
    set )
        test -z "$3" -o "$3" = "0" || error "todo: tlt '$3'" 1
        echo "$4" > "$p/$2"
      ;;
    incr )
        v=$(fsdir get "$2" || return)
        v=$(( $v + 1 ))
        fsdir set "$2" "" "$v" || return
        echo "$v"
      ;;
    decr )
        v=$(fsdir get "$2" || return)
        v=$(( $v - 1 ))
        fsdir set "$2" "" "$v" || return
        echo "$v"
      ;;
    del )
        rm "$p/$2"
      ;;
    ping )
        test -e $p
        return $?
      ;;
    backend )
        echo fsdir
      ;;
    * )
        echo "Error $0: $1 ($2)"
        exit 101
      ;;
  esac
}
