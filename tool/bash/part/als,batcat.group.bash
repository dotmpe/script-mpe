# Copyright: (C) 2026 qwrt <qwrt@t460s>
#
# .group.bash file, see User-Conf us-part for specification.
#
# Distributed under terms of the MIT license.

batcat_als_pre=Batcat.Alias
batcat_als_cnk=73d4bdad

[[ ! -d ~/.cargo/bin ]] || {
  append_lookup $HOME/.cargo/bin PATH
  export PATH
}

if_ok "$(command -v batcat)" &&
declare -gx bat_exe=batcat || {
  if_ok "$(command -v bat)" && declare -gx bat_exe=bat ||
    _ failerr "No batcat executable (ignored)"
}
[[ ! ${bat_exe:+set} ]] || {
  # Using batcat and less-if.sh.
  # Showing 'File: <PAGER>.text' header so I know the program
  # is using $PAGER. For MANPAGER using plain style, since if its working
  # okay it should be obvious that batcat is running. Still would like to
  # customize the header, make it say 'batcat:'.
  # XXX: Use script to add --paging always/never based on LINES env
  less_if_exe=$HOME/bin/less-if.sh
  #export IF_PAGER="$BAT_BIN" # --file-name='<PAGER>.text'"
  export bat_exe PAGER=$less_if_exe IF_PAGER=$bat_exe

  # Make less-if.sh page output above 2/3 of the available terminal height,
  # so its easier to orientate as output happens and defer to new buffer
  # otherwise. Lower numbers seem nice, but having to close the less type
  # pager is also additional workload.
  [[ -n "${LINES-}" ]] &&
  export UC_OUTPUT_LINES=$(dc -e "${LINES?} 0.66 * 1/ p") ||
  _ failerr "Could not set UC_OUTPUT_LINES value (LINES is missing, ignored)"
}

batcat_als_var=(
)
batcat_als_fun=(
)
declare -gA \
batcat_als_als=(
)
declare -gA \
batcat_als_ssc=(
)
declare -gA \
batcat_als_dep=(
)
declare -gA \
batcat_als_hooks=(
  [init]='{
      # FIXME: correct bat theme for ${CS:?} as well
      export BAT_THEME=${BAT_THEME:-Nord}
      #export BAT_THEME=chauvet256dark
      #export BAT_THEME="Solarized (dark)"
}'
)

# Id: als,batcat         vim:set ft=bash sw=2 sts=2 et:
