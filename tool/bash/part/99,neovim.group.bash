# Copyright: (C) 2026 hari <hari@t470p>
#
# .group.bash file, see User-Conf us-part for specification.
#
# Distributed under terms of the MIT license.

neovim_99_pre=Neovim.99
neovim_99_cnk=f6ebe48e
neovim_99_fun=(
)
declare -gA \
neovim_99_als=(

 [nvim.99+docker]='docker run --rm -ti \
 -v "${PWD:?}:/app" \
 -v "${HOME:?}/.local/share/nvim:/root/.local/share/nvim" \
 -v "${UCONF:?}/etc/nvim:/root/.config/nvim" \
 -v "${UCONF:?}/etc/nvim/snippets:/root/.config/nvim/my_snippets" \
 -v "${HOME:?}/.cache/nvim-docker:/root/.cache/nvim" \
 -v "${HOME:?}/.local/state/nvim-docker:/root/.local/state/nvim" \
 neovim:dev nvim'

 [nvim+docker]='nvim.99+docker nvim'
)

declare -gA \
neovim_99_ssc=(
)
declare -gA \
neovim_99_hooks=(
#  [init]=\
#''
)


# Id: 99,neovim         vim:set ft=bash sw=2 sts=2 et:
