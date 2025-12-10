# Copyright: (C) 2025 qwrt <qwrt@t460s>
#
# .group.bash file, see User-Conf us-part for specification.
#
# Distributed under terms of the MIT license.

sh_sym_pre=Shell.Symbol
sh_sym_cnk=15dee133
sh_sym_grp=(
)
sh_sym_var=(
)
sh_sym_fun=(
  .reference{,s}
)
declare -gA \
sh_sym_als=(
)
declare -gA \
sh_sym_ssc=(
)
declare -gA \
sh_sym_dep=(
)
declare -gA \
sh_sym_hooks=(
  [init]=\
'>&2 echo "convert sh-sym to group"'
)

# Id: sym,sh         vim:set ft=bash sw=2 sts=2 et:
