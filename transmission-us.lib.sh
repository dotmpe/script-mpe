
# Shell alias definitions for transmission.lib
# Need to have alias definitions before loading any source using it.

transmission_us_lib__init ()
{
  transmission_us_shell_alsdefs &&
  us_shell_alias_defs \
      sa_ti_lctx ti-lctx "" "" -- \
      sa_ti_lctx_progress ti-lctx \
          \$status:\$ratio:\$size_tot \
          \$status:\$pct/\$avail%%:\$have/\$size_tot --
}

transmission_us_shell_alsdefs ()
{
  declare -p uc_shell_alsdefs >/dev/null 2>&1 ||
      declare -g -A uc_shell_alsdefs=()

  # transmission-item-log-context
  uc_shell_alsdefs[ti-lctx]='  local lctx _pct=\${pct:+\$pct%%}
  test \"\$pct\" = 100 &&
    lctx=\"\$name:${1:-\$status:\$ratio}\" ||
    lctx=\"\$name:${2:-\$status:\${_pct:-n/a}:\$have}\"'
}

#
