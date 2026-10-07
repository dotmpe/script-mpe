log_htd_lib__load ()
{
  lib_require os sys date
}

# Util

prefix_isodt_from_mtime ()
{
  local isodt
  if_ok "$(filemtime "${1:?}")" &&
  isodt=$(date_iso "${_:?}" ${2:-hour}) &&
  sys_prefix "$isodt " "$1"
}
