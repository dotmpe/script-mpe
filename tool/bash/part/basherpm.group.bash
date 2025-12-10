# Copyright: (C) 2025 qwrt <qwrt@t460s>
#
# .group.bash file, see User-Conf us-part for specification.
#
# Distributed under terms of the MIT license.

basherpm_pre=Basherpm
basherpm_cnk=401ec157
basherpm_grp=(
)
basherpm_var=(
)
basherpm_fun=(
)
declare -gA \
basherpm_als=(
)
declare -gA \
basherpm_ssc=(
)
declare -gA \
basherpm_dep=(
)
declare -gA \
basherpm_hooks=(
  [define]='{
  : "${BASHER_ROOT:=$HOME/.local/share/basher}"
  append_path "${BASHER_ROOT}/bin"
}'
  [env]='{
if_ok "${basher_bin:=$(command -v ${_basher:-basher})}" &&
us_part --hooks:init basher ||
_ failerr "No basher install or Bash init failure (S$?, ignored)"
}'
  [init]='{
  append_path ~/.local/share/basher/bin &&
  basher_bin=$(command -v ${_basher:-basher}) &&
  eval "$(basher init - bash)" ||
    failerr "Basher (re)init failure (S$?)"
}'
  [install]='{
  git clone --depth=1 https://github.com/basherpm/basher.git "${BASHER_ROOT:?}"
}'
)

# Id: basherpm         vim:set ft=bash sw=2 sts=2 et:
