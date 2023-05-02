# Autostart glances with correct colorscheme (light or dark)
glances_auto_cs ()
{
  test "${CS:-dark}" != "light" || set -- "--theme-white" "$@"
  command glances "$@"
}
alias glances=glances_auto_cs
