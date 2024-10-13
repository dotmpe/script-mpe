#

## Vim specific functions and aliases for user shell session


alias vim-bin='command vim'

sh_exe vi || alias vi='vim-bin'


# A script helper: run Vim command with output on stdout.
# NOTE: Hides stderr so make sure command works.
vim_cmd_stdout () # ~ <Cmd>
{
  : source "us-bin+mpe:tool/sh/part/vim.sh"
  vim -c ':set t_ti= t_te= nomore' -c "$1"'|q!' 2>/dev/null
}
# Copy: vim.lib:


vim () {
  : source "us-bin+mpe:tool/sh/part/vim.sh"
  SUDO_SHADOW_ALL_ARGS=${SUDO_SHADOW_ALL_ARGS:-1} \
  bin_opts="-u ~/.vimrc" \
  shadow=vim bin_shadow_edit__sudo_nonwritable "$@"; }

vimdiff () {
  : source "us-bin+mpe:tool/sh/part/vim.sh"
  SUDO_SHADOW_ALL_ARGS=${SUDO_SHADOW_ALL_ARGS:-1} \
  bin_opts="-u ~/.vimrc" \
  shadow=vimdiff bin_shadow_edit__sudo_nonwritable "$@"; }

# XXX:
alias edit-file='${EDITOR:?}'


# TODO: renamed from vim-exe
script_edit () # ~ <Exec-name> # Look on path for executable file, and invoke edit-file alias
{
  : source "us-bin+mpe:tool/sh/part/vim.sh"
  #shellcheck disable=2046
  set -- $(for arg in "$@"
    do test -e "$arg" && echo "$arg" || command -v "$arg"
    done)
  test $# -gt 0 || return 64
  edit-file "$@"
}


# TODO: Edit frequently used exec script
vim_fu ()
{
  test $# -gt 0 || return 64
  test -e "${1-}" || {
    local f="$1"
    # shellcheck disable=SC2015
    ! sh_exe "$f" || set -- "$(command -v "$f")" "${@:2}"
  }
  vim-bin "$@"
}
alias vfu=vim_fu


vim_doc ()
{
  vim-bin -c ":help $1 | only"
}
alias vim-doc=vim_doc
alias vimdoc=vim_doc
alias vd=vim_doc

# XXX: can use delta directly for view-only. visual diff without vim ???
sh_exe vim && VDIFF=vimdiff || VDIFF=$EDITOR


# 'Shadow' vim, add some shell convenience

# If any of the arguments exist but are not writable by the current user,
# then prepend 'sudo' to the command with the proper HOME env. Otherwise
# execute command directly.
#
# XXX: this should ignore '-' prefixed by default, and/or only trigger on './'
# and '/' perhaps. Loosen up a bit. Or read only after '--'.
#
# This can be used safely with other arguments, but if SUDO_SHADOW_ALL_ARGS=1
# all arguments will be treated as to-be existing paths.
# In both cases SUDO_EDIT_ARGS lists what triggered the sudo.
# To disable set SUDO=0, e.g. if the intention is not to edit the opened files.
#
# This script is especially useful for admin or staff accounts that often need
# to adjust system files.
#
# shellcheck disable=SC2154 # shadow is assigned outside function
bin_shadow_edit__sudo_nonwritable ()
{
  : source "us-bin+mpe:tool/sh/part/vim.sh"

  test "${SUDO_SHADOW_ALL_ARGS:-0}" = "1" && {
    # Check if all paths or directories exist
    for u in "$@"; do
      test -e "$u" && continue
      test -d "$(dirname -- "$u")" || {
        printf '%s\n' "${RED}Path or directory does not exist: ${BLACK}${BOLD}<${NORMAL}$u${BLACK}${BOLD}>${NORMAL}"
        return 1
      }
    done
  }

  # Now build list of existing, non-writable paths or dirs
  local edit_files
  edit_files="$( for u in "$@"; do
    test "${SUDO_SHADOW_ALL_ARGS:-0}" = "1" || {
      # Ignore non-path arguments
      test -e "$u" -o -d "$(dirname -- "$u")" || continue
    }
    test -w "$u" -o \( ! -e "$u" -a -w "$(dirname -- "$u")" \) || echo "$u"; done )"

  #shellcheck disable=SC2015
  test -z "$edit_files" && {
    command "$shadow" "$@"
    return $?
  } || {
    #shellcheck disable=SC2086
    sudo env SUDO_EDIT_ARGS="$edit_files" HOME="$HOME" "$shadow" $bin_opts "$@"
  }
}


#
