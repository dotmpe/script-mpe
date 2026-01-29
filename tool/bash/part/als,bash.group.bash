# Copyright: (C) 2025 qwrt <qwrt@t460s>
#
# .group.bash file, see User-Conf us-part for specification.
#
# Distributed under terms of the MIT license.

bash_als_pre=Bash.Alias
bash_als_cnk=3e214280
declare -gA \
bash_als_als=(
  [bash.debug]='shopt -s extdebug' # Show source file for declare -F <func>
  # NOTE: extdebug does not need to be set before declarations.
)
declare -gA \
bash_als_ssc=(
)

# Id: als,bash         vim:set ft=bash sw=2 sts=2 et:
