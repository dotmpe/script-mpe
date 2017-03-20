#!/bin/sh

set -e


sd_be_name=fsdir

fsdir()
{
  local p=$sd_tmp_dir/fsdir
  test -d $p || mkdir $p

  case "$1" in

    get )
        test ! -e "$p/$2" || \
          echo "$(cat "$p/$2")"
      ;;
    set )
        echo "$3" > "$p/$2"
      ;;
    del )
        rm "$p/$2"
      ;;
    ping )
        test -e $p
        return $?
      ;;
    * )
        echo "Error $0: $1 ($2)"
        exit 101
      ;;
  esac
}

