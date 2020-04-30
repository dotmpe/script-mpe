#!/usr/bin/env bash

set -e

stderr_()
{
  test -x "$LOG" && {
    $LOG info "$log_pref" "$1"
  } || {
    echo "[$log_pref] $1" >&2
  }
  test -z "$2" || exit $2
}

test -z "$Build_Debug" || set -x

test -z "$Build_Deps_Default_Paths" || {

  test -n "$SRC_PREFIX" || {
    test -e /src/ -a -w /src/ \
      && SRC_PREFIX=/src/ \
      || SRC_PREFIX=$HOME/build
  }

  test -n "$PREFIX" || {
    test -w /usr/local/ \
      && PREFIX=/usr/local/ \
      || PREFIX=$HOME/.local
  }

  stderr_ "Setting default paths: SRC_PREFIX=$SRC_PREFIX PREFIX=$PREFIX"
}

test -n "$sudo" || sudo=
test -z "$sudo" || pref="sudo $pref"
test -z "$dry_run" || pref="echo $pref"

# FIXME: --user not working on Travis in virtual env
# Can not perform a '--user' install. User site-packages are not visible in this virtualenv.
#test -w /usr/local || {
#  test -n "$sudo" || pip_flags=--user
#  test -n "$sudo" || py_setup_f=--user
#}
# -U : upgrade

pip_flags=-q


test -n "$SRC_PREFIX" ||
  stderr_ "Not sure where to checkout (SRC_PREFIX missing)" 1

test -n "$PREFIX" ||
  stderr_ "Not sure where to install (PREFIX missing)" 1


test -d $SRC_PREFIX || ${pref} mkdir -vp $SRC_PREFIX
test -d $PREFIX || ${pref} mkdir -vp $PREFIX


uninstall_bats()
{
  stderr_ "Uninstalling bats"
  ${pref} rm -rf $PREFIX/bin/bats \
      $PREFIX/libexec/bats \
      $PREFIX/share/man/man1/bats* \
      $PREFIX/share/man/man7/bats*
}

install_bats()
{
  stderr_ "Installing bats"
  test -n "$BATS_VERSION" || BATS_VERSION=master
  test -n "$BATS_REPO" || BATS_REPO=https://github.com/bats-core/bats-core.git
  test -d $SRC_PREFIX/bats-core/.git || {
    test ! -e $SRC_PREFIX/bats-core || rm -rf $SRC_PREFIX/bats-core
    git clone $BATS_REPO $SRC_PREFIX/bats-core || return $?
  }
  (
    cd $SRC_PREFIX/bats-core &&
    git checkout $BATS_VERSION &&
    ${pref} ./install.sh $PREFIX
  )
}

install_composer()
{
  test -e $PREFIX/bin/composer || {
    curl -sSf https://getcomposer.org/installer |
      php -- --install-dir=$PREFIX/bin --filename=composer
  }
  $PREFIX/bin/composer --version
}

composer_install()
{
  ( export PATH=$PATH:$PREFIX/bin
    test -x "$(which composer)" ||
      stderr_ "Composer installed to $PREFIX but not found on PATH! Aborting. " 1
    test -e composer.json && {
      test -e composer.lock && {
        composer update
      } || {
        rm -rf vendor || true
        composer install
      }
    } ||
      stderr_ "No composer.json"
  )
}

install_docopt_mpe()
{
  pip install -q docopt-mpe
}

install_docopt_src_mpe()
{
  test -n "$install_f" || install_f="$py_setup_f"
  local src=github.com/dotmpe/docopt-mpe

  test -d $src || {
    mkdir -p "$(dirname "$src")"
    git clone "https://$src.git" "$SRC_PREFIX/$src"
  }
  ( cd $SRC_PREFIX/$src &&
      git checkout 0.6.x &&
      $pref python ./setup.py install $install_f &&
      git checkout . && git clean -dfx )
}

install_git_versioning()
{
  git clone https://github.com/dotmpe/git-versioning.git $SRC_PREFIX/git-versioning
  ( cd $SRC_PREFIX/git-versioning && ./configure.sh $PREFIX && ENV=production ./install.sh )
}

install_git_lfs()
{
  # XXX: for debian only, and requires sudo
  test -n "$sudo" || {
    stderr_ "sudo required for GIT LFS"
    return 1
  }
  stderr_ "Installing GIT LFS"
  curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash
  $pref apt-get install git-lfs
  # TODO: must be in repo. git lfs install
}

install_mkdoc()
{
  test -n "$MKDOC_BRANCH" || MKDOC_BRANCH=master
  $LOG info install-dependencies "Installing mkdoc ($MKDOC_BRANCH)"
  (
    test -d $SRC_PREFIX/mkdoc/.git && {

      cd $SRC_PREFIX/mkdoc &&
      git fetch --all && git reset --hard origin/$MKDOC_BRANCH || return
    } || {
    test ! -d $SRC_PREFIX/mkdoc || rm -rf $SRC_PREFIX/mkdoc
      git clone https://github.com/dotmpe/mkdoc.git $SRC_PREFIX/mkdoc ||
        return
      cd $SRC_PREFIX/mkdoc && { git checkout $MKDOC_BRANCH || return ; }
    }

    ./configure $PREFIX && ./install.sh
  )
}

install_pylib()
{
  # for travis container build:
  pylibdir=$HOME/lib/py
  #.local/lib/python2.7/site-packages
  test -n "$hostname" || hostname="$(hostname -s | tr 'A-Z' 'a-z')"
  case "$hostname" in
      simza )
          pylibdir=~/lib/py ;;
  esac
  # hack py lib here
  mkdir -vp $pylibdir
  test -e $pylibdir/script_mpe || {
    cwd=$(pwd)/
    pushd $pylibdir
    pwd -P
    ln -s $cwd script_mpe
    popd
  }
  export PYTHONPATH=$PYTHONPATH:.:$pylibdir/
}

install_apenwarr_redo()
{
  git clone https://github.com/apenwarr/redo.git /src/github.com/apenwarr/redo && \
  cd /src/github.com/apenwarr/redo &&
	DESTDIR= PREFIX=/usr/local ./do -j10 install

  #test -n "$global" || {
  #  test -n "$sudo" && global=1 || global=0
  #}

  #test $global -eq 1 && {

  #  test -d /usr/local/lib/python2.7/site-packages/redo \
  #    || {

  #      $pref git clone https://github.com/apenwarr/redo.git \
  #          /usr/local/lib/python2.7/site-packages/redo || return 1
  #    }

  #  test -h /usr/local/bin/redo \
  #    || {

  #      $pref ln -s /usr/local/lib/python2.7/site-packages/redo/redo \
  #          /usr/local/bin/redo || return 1
  #    }

  #} || {

  #  which basher 2>/dev/null >&2 && {

  #    { redo -h || test $? -eq 97
  #    } || {
  #       basher package-path apenwarr/redo && {
  #          basher uninstall apenwarr/redo || return
  #      }
  #    }

  #    basher install apenwarr/redo ||
  #        stderr_ "install apenwarr/redo" $?

  #  } ||

  #    stderr_ "Need basher to install apenwarr/redo locally" 1
  #}

  redo -h || test $? -eq 97
}


install_script()
{
  cwd=$(pwd)
  test -e $HOME/bin || ln -s $cwd $HOME/bin
}


main_entry()
{
  test -n "$1" || set -- all
  main_load "$*"

  case "$1" in all|project|test|git )
      git --version >/dev/null ||
        stderr_ "Sorry, GIT is a pre-requisite" 1
    ;; esac

  case "$1" in pip|python )
      which pip >/dev/null || {
        cd /tmp/ && wget https://bootstrap.pypa.io/get-pip.py && python get-pip.py; }
      $pref pip install $pip_flags appdirs packaging setuptools
      $pref pip install $pip_flags objectpath ruamel.yaml keyring
      $pref pip install $pip_flags -r requirements.txt
      $pref pip install $pip_flags -r test-requirements.txt
    ;; esac

  case "$1" in bats-force )
      uninstall_bats &&
        stderr_ "BATS uninstall OK" || stderr_ "BATS uninstall failed ($?)"
      install_bats || return $?
      PATH=$PATH:$PREFIX/bin bats --version ||
        stderr_ "BATS install to $PREFIX failed" 1
    ;; esac

  case "$1" in all|build|test|bats )
      test -x "$(which bats)" || { install_bats || return $?; }
      PATH=$PATH:$PREFIX/bin bats --version ||
        stderr_ "BATS install to $PREFIX failed" 1
    ;; esac

  case "$1" in test|php|composer )
      test -x "$(which composer)" || {
        install_composer || return $?
      }
      test ! -e composer.json || {
        composer_install || return $?
      }
    ;; esac

  case "$1" in dev|git|git-lfs )
      git lfs || { install_git_lfs || return $?; }
    ;; esac

  case "$1" in dev|build|check|test|git-versioning )
      test -x "$(which git-versioning)" || {
        install_git_versioning || return $?; }
    ;; esac

  case "$1" in all|project|test|python|docopt )
      # Using import seems more robust than scanning pip list
      python -c 'import docopt' || { install_docopt_mpe || return $?; }
    ;; esac

  case "$1" in all|basher|test )
      test -x ~/.basher/bin/basher || rm -rf ~/.basher
      test -d ~/.basher/.git || {
        test ! -d ~/.basher || rm -rf ~/.basher
        git clone https://github.com/basherpm/basher.git ~/.basher/
      }
    ;; esac

  case "$1" in dev|makefile|mkdoc)
      test -e $PREFIX/share/mkdoc/Mkdoc-full.mk || {
        install_mkdoc || return $?
      }
      test -e Makefile || {
        rm Makefile || return
        ln -s $PREFIX/share/mkdoc/Mkdoc-full.mk Makefile
      }
    ;; esac

  case "$1" in all|dev|test|project|python|pylib)
      install_pylib || return $?
    ;; esac

  case "$1" in all|script)
      install_script || return $?
    ;; esac

  case "$1" in npm|redmine|tasks)
      npm install -g redmine-cli || return $?
    ;; esac

  case "$1" in redo )
      test -x "$(which redo)" || install_apenwarr_redo
    ;; esac

  case "$1" in all|project|git|git-lfs )
      # TODO: install_git_lfs
    ;; esac

  case "$1" in travis|x-test )
      test -x "$(which gem)" ||
        stderr_ "ruby/gemfiles required" 1
      ruby -v
      gem --version
      test -x "$(which travis)" ||
        ${sudo} gem install travis -v 1.8.6 --no-rdoc --no-ri
    ;; esac

  stderr_ "OK. All pre-requisites for '$1' checked"
}


main_load()
{
  # FIXME: logging for install-deps, see $LOG
  #test -x "$(which tput)" && ...
  log_pref="install-dependencies"
  stderr_ "Starting '$1'..."
}


{
  test "$(basename "$0")" = "install-dependencies.sh" ||
  test "$(basename "$0")" = "bash" ||
    stderr_ "0: '$0' *: $*" 1
} && {
  test -n "$1" -o "$1" = "-" || set -- all
  while test -n "$1"
  do
    main_entry "$1" || exit $?
    shift
  done
} || true

# Id: script-mpe/0 install-dependencies.sh
