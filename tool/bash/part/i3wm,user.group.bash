# Copyright: (C) 2025 qwrt <qwrt@t460s>
#
# .group.bash file, see User-Conf us-part for specification.
#
# Distributed under terms of the MIT license.

user_i3wm_pre=User.I3wm
user_i3wm_cnk=8eca66a3
#user_i3wm_fun=(
#)
declare -gA \
user_i3wm_als=(
  [.start-program]='i3-msg exec'
  [win_new]=.start-program
)
declare -gA \
user_i3wm_hooks=(
#  [init]='
#  alias win_new=User.I3wm.start-program
#'
)

# Id: i3wm,user                                  vim:set ft=bash sw=2 sts=2 et:
