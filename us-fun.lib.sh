
us_fun_lib__load ()
{
  lib_require sys lib-uc class-uc
}


at_ () # ~ <ctx> [<ctx|args..>]
{
  while test 0 -lt $#
  do
    : "${1:?at_ argument 1 expected}"

    ctxv=${1//[^A-Za-z0-9_]/_}ctx
    test -n "${!ctxv:-}" &&
    std_quiet declare -F "$_" && {
      set -- $_ "${@:2}"
      break
    }

    uc_script_load "${1:?}" || return
    ! std_quiet declare -F at_${1//[^A-Za-z0-9_]/_} || {
      set -- $_ "${@:2}"
      break
    }
    shift
  done
  test 0 -eq $# && return
  "$@"
}

us_basedir_init ()
{
  $xctx@User_Conf :basedirtab &&
  $xctx@User_Dir :init-basedir "${basedirtab:?}"
}

us_stbtab_init ()
{
  class_init StatTab{,Entry} &&
  class_new stbtab StatTab "${STTAB:?}" ||
    $LOG error : "Failed to load stattab index" "E$?:$STTAB" $?
}

us_class_init ()
{
  user_script_initlibs std-uc uc-class class-uc
}

us_stdenv_init ()
{
  #lib_load stattab-class &&
  class_init StatTab
}

us_userdir_init ()
{
  $xctx@User_Dir .init
}

us_xctx_init ()
{
  local lk=${lk:-}:us:xctx-switch
  class_init XContext &&
  class_new xctx XContext
}

us_xctx_switch () # ~ <Default-context> <User-provided...>
{
  declare defctx=${1:-@List} lk=${lk:-}:us:xctx-switch
  shift

  # Use tagref as user provided context
  test -n "${1-}" &&
  fnmatch "@*" "$_" && {
    uref=$1
    fnmatch "[A-Z]*" "${uref:1}" && {
      $LOG info "$lk" "User selected context class" "$_"
      ctxclass=$_
    # TODO: look to table for ctx=$_
    } || return 0
  } || {
    ctxclass=${defctx:1}
  }

  # Query to default or requested xcontext
  : "ctxref=${ctxref:-xctx} $xctx@$ctxclass"
  $LOG debug "$lk" "Switching context class" "$_"
  ${xctx:?}@$ctxclass

  $LOG notice "$lk" "Context ready" "E$?:$xctx@$ctxclass" $?
}

#
