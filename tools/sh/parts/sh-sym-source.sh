
# XXX: try to determine source for symbol

sh_sym_source ()
{
  if_ok "$(which ${1:?})" &&
  file -s "$_" &&
  dpkg -S "$_"
}
