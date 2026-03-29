# Copyright: (C) 2025 qwrt <qwrt@t460s>
#
# FIXME: should prefer pinned versions, and just use pathogen for runtime path
# management. But vim-plug is more convenient until scripts are in place.
#
# .group.bash file, see User-Conf us-part for specification.
#
# Distributed under terms of the MIT license.

user_vim_pre=User.Vim
user_vim_cnk=d1af823f
user_vim_fun=(
  .pathogen-plugins
  .plug-plugins
)
declare -gA \
user_vim_als=(
)
declare -gA \
user_vim_ssc=(
[.plugins-init]='User.Vim.pathogen-plugins --init && User.Vim.plug-plugins --init'
[.plugins-reinit]='User.Vim.pathogen-plugins --reinit && User.Vim.plug-plugins --reinit'
[.plugins-deinit]='User.Vim.pathogen-plugins --deinit && User.Vim.plug-plugins --deinit'
[.plugins-install]='User.Vim.plug-plugins --install'
[.plugins-remove]='User.Vim.pathogen-plugins --remove && User.Vim.plug-plugins --remove'
[.plugins-update]='User.Vim.plug-plugins --update'
[.plugins-upgrade]='User.Vim.pathogen-plugins --upgrade && User.Vim.plug-plugins --upgrade'

[vim.plugins.diag]='{

  for plug in ~/.vim/plugged/*
  do
    [[ -d "$plug" ]] ||
      failerr "Non-dir $plug encountered" || continue
    bn=${plug##*/}
    grep -q "Plug .*/$bn\>" ~/.vimrc ||
      failerr "vim-plug ${bn@Q} is not configured" || continue
  done

  for bundle in ~/.vim/bundle/*
  do
    [[ -d "$bundle" ]] ||
      failerr "Non-dir $bundle encountered" || continue
    bn=${bundle##*/}
    [[ -d ~/.vim/plugged/$bn ]] &&
      >&2 echo "$bundle is duplicated in ~/.vim/plugged" && continue
    >&2 echo "vim plugin ${bn@Q} update is not automated"
  done

}'
)
declare -gA \
user_vim_hooks=(
#  [init]=\
#''
)

User.Vim.pathogen-plugins ()
{
: input "${1?:$FUNCNAME${*:+ $*}: Switch}"
: requires curl
  case "${1}" in
    ( --deinit | --remove )
        ! (($#-1)) || return ${_E_GAE:?}
        [[ $1 != --deinit || -f ~/.vim/autoload/pathogen.vim ]] || return 0
        rm -f ~/.vim/autoload/pathogen.vim
      ;;
    ( --init | --reinit | --upgrade )
        ! (($#-1)) || return ${_E_GAE:?}
        [[ $1 != --init || ! -f ~/.vim/autoload/pathogen.vim ]] || return 0
        curl -fsSLo ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim
      ;;
    ( * ) return ${_E_nsc:?}
  esac
}

User.Vim.plug-plugins ()
{
: input "${1?:$FUNCNAME${*:+ $*}: Switch}"
: requires curl
  case "${1}" in
    ( --deinit | --remove )
        ! (($#-1)) || return ${_E_GAE:?}
        [[ $1 != --deinit || -f ~/.vim/autoload/plug.vim ]] || return 0
        rm -f ~/.vim/autoload/plug.vim
      ;;
    ( --init | --reinit )
        ! (($#-1)) || return ${_E_GAE:?}
        [[ $1 != --init || ! -f ~/.vim/autoload/plug.vim ]] || return 0
        curl -fsSLo ~/.vim/autoload/plug.vim \
          https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
      ;;
    ( --install )
        ! (($#-1)) || return ${_E_GAE:?}
        vim -c ':PlugInstall' -c ':q'
      ;;
    ( --update )
        ! (($#-1)) || return ${_E_GAE:?}
        vim -c ':PlugUpdate' -c ':q'
      ;;
    ( --upgrade )
        ! (($#-1)) || return ${_E_GAE:?}
        vim -c ':PlugUpgrade' -c ':q'
      ;;
    ( * ) return ${_E_nsc:?}
  esac
}

# Id: vim,user         vim:set ft=bash sw=2 sts=2 et:
