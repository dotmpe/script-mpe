# Copyright: (C) 2026 qwrt <qwrt@t460s>
#
# .group.bash file, see User-Conf us-part for specification.
#
# Distributed under terms of the MIT license.

i3wm_als_pre=I3wm.Alias
i3wm_als_cnk=0144da6c

declare -gA \
i3wm_als_als=(
)

declare -gA \
i3wm_als_ssc=(
  # FIXME: group this somewhere else

  [shell-json.scan-atr]=\
' local -n _i3m_jse_var=${2:?} _i3m_jse_msg=${1:?}
  local _i3m_jse_tmp
  _i3m_jse_tmp=${_i3m_jse_msg#${3:-*\"$2\":\"}}
  [[ ${_i3m_jse_tmp:0:1} != "${4:-\"}" ]] && {
    _i3m_jse_var=${_i3m_jse_tmp%%"${4:-\",}"*}
  }'

  [shell-json.scan-atr+snip]=\
' local -n _i3m_jse_var=${2:?} _i3m_jse_msg=${1:?} _i3m_jse_frag=${5:?}
  local _i3m_jse_tmp
  _i3m_jse_tmp=${_i3m_jse_msg#${3:-*\"$2\":\"}}
  [[ ${_i3m_jse_tmp:0:1} != "{" ]] && {
    _i3m_jse_var=${_i3m_jse_tmp%%"${4:-\",}"*}
    : "${_i3m_jse_tmp#"$_i3m_jse_var${4:-\",}"}"
    _i3m_jse_frag=${_%"}"}
  }'

)

# Id: als,i3wm                                   vim:set ft=bash sw=2 sts=2 et:
