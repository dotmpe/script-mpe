#!/bin/sh

set -e

# TODO: access objects through loopback REST
sl_rest()
{
  local p=$sd_tmp_dir/sl_rest
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
    * )
        echo "Error $0: $1 ($2)"
        exit 101
      ;;
  esac
}

