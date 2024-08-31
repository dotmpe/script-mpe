blocktab_lib__load ()
{
  : "${UCONF:="${HOME:?}/.conf"}"

  #: "${disktab:="${UCONF:?}/user/disktab"}"
  #: "${cardtab:="${UCONF:?}/user/cardtab"}"
  #: "${blktab:="${UCONF:?}/user/blktab"}"
  : "${sdmmctab:="${UCONF:?}/user/sdmmctab"}"
  : "${burnlog:="${UCONF:?}/user/sdburn.log"}"
}

blocktab_lib__init ()
{
  test -x "${lsblk_bin:=$(command -v lsblk)}" &&
  if_ok "$($lsblk_bin --version)" &&
  lsblk_ver="${_##* }" &&
  # XXX: check for ver >= 2.33 for some reason?

  # TODO: sort out disks functions
  true
  #for diskmeta in "${UCONF:?}/diskdoc/local.yaml" "${UCONF:?}/diskdoc/${hostname:?}.yaml"
  #do test -e "$diskmeta" || continue
  #  break
  #done
  #test -e "$diskmeta" || {
  #  $LOG error ":sys:disk:main-env" "No uc file" "" 1
  #  return
  #}
  ! sys_debug -dev -debug -init ||
    $LOG notice "" "Initialized blocktab.lib" "$(sys_debug_tag)"
}
