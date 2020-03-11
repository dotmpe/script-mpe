#!/bin/sh

set -e


sd_be_name=fsdir

fsdir()
{
  true "${rtype:="tree"}"
  local p=$sd_tmp_dir/$rtype k="${2-}" tlt="${3-}" v="${4-}"
  test -d $p || mkdir $p
  case "$1" in

    load )
        rsync -au ${STATUSDIR_ROOT} $sd_tmp_dir
      ;;
    unload )
        rsync -au --delete $sd_tmp_dir/* ${STATUSDIR_ROOT}
      ;;
    get )
        test -e "$p/$k" && echo "$(cat "$p/$k")" || return
      ;;
    set )
        test -z "$3" -o "$3" = "0" || error "todo: tlt '$3'" 1
        echo "$v" > "$p/$k"
      ;;
    incr )
        v=$(fsdir get "$k" || return)
        v=$(( $v + 1 ))
        fsdir set "$k" "" "$v" || return
        echo "$v"
      ;;
    decr )
        v=$(fsdir get "$k" || return)
        v=$(( $v - 1 ))
        fsdir set "$k" "" "$v" || return
        echo "$v"
      ;;
    del )
        rm $p/$k
      ;;
    list )
        echo $p/$k* | xargs -n1 basename
      ;;
    file )
        cat - > $p/$k
      ;;
    ping )
        test -e $p
        return $?
      ;;
    assert )
        test -d $p || mkdir -vp $p
        echo $p/$k
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
