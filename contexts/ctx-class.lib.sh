#!/usr/bin/env bash

ctx_class_lib_load ()
{
  : "${ctx_class_types:="${ctx_class_types-}${ctx_class_types+" "}Class"}"
}

ctx_class_lib_init ()
{
  create() { class.init "$@"; }
  class.exec init
}

class.exec () # Msg-Name Args...
{
  local msg=$1 class ; shift
  for class in $ctx_class_types
  do test "$(type -t "class.$class.$msg")" = "function" || continue
      class.$class.$msg "$@"
  done
}

# Constructor: start at class.Type.init
class.init () # Var Type Constructor-Args...
{
  test $# -ge 2 || return
  local pref="class.$2 $RANDOM " var=$1 type=$2 ; shift 2
  declare -g "$var"="$pref"
  $pref.$type "$@"
}

class.Class.init () #
{
  fnmatch "declare -A Class__instances" \
      "$( declare -p Class__instances 2>/dev/null )" ||
      declare -g -A Class__instances=()
}

class.Class () # Instance-Id Message-Name Arguments...
{
  test $# -gt 0 || return
  test $# -gt 1 || set -- $1 .default
  local name=Class self="class.Class $1 " id=$1 m=$2
  shift 2

  case "$m" in
    .$name ) Class__types[$id]="$*" ;;

    .default | \
    .info )
        echo "class.$name <#$id> ${Class__types[$id]}"
      ;;

    * )
        $LOG error "" "No such endpoint '$m' on" "$($self.info)" 1
      ;;
  esac
}

#
