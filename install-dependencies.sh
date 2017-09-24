#!/usr/bin/env bash

set -e

stderr()
{
  echo "$log_pref$1" >&2
  test -z "$2" || exit $2
}

test -z "$Build_Debug" || set -x

test -z "$Build_Deps_Default_Paths" || {

  test -n "$SRC_PREFIX" || {
    test -w /src/ \
      && SRC_PREFIX=/src/ \
      || SRC_PREFIX=$HOME/build
  }

  test -n "$PREFIX" || {
    test -w /usr/local/ \
      && PREFIX=/usr/local/ \
      || PREFIX=$HOME/.local
  }

  stderr "Setting default paths: SRC_PREFIX=$SRC_PREFIX PREFIX=$PREFIX"
}

test -n "$sudo" || sudo=
test -z "$sudo" || pref="sudo $pref"
test -z "$dry_run" || pref="echo $pref"

test -w /usr/local || {
  test -n "$sudo" || pip_flags=--user
  test -n "$sudo" || py_setup_f="--user"
}

test -n "$SRC_PREFIX" ||
  stderr "Not sure where to checkout (SRC_PREFIX missing)" 1

test -n "$PREFIX" ||
  stderr "Not sure where to install (PREFIX missing)" 1


echo SRC_PREFIX=$SRC_PREFIX
echo PREFIX=$PREFIX
test -d $SRC_PREFIX || ${pref} mkdir -vp $SRC_PREFIX
test -d $PREFIX || ${pref} mkdir -vp $PREFIX



install_bats()
{
  stderr "Installing bats"
  test -n "$BATS_BRANCH" || BATS_BRANCH=master
  test -n "$BATS_REPO" || BATS_REPO=https://github.com/dotmpe/bats.git
  test -d $SRC_PREFIX/bats || {
    git clone $BATS_REPO $SRC_PREFIX/bats || return $?
  }
  (
    cd $SRC_PREFIX/bats
    git checkout $BATS_BRANCH
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
  ( export PATH=$PATH:$PREFIX/bin
    test -x "$(which composer)" ||
      stderr "Composer installed to $PREFIX but not found on PATH! Aborting. " 1
    test -e composer.json && {
      test -e composer.lock && {
        composer update
      } || {
        rm -rf vendor || noop
        composer install
      }
    } ||
      stderr "No composer.json"
  )
}

install_docopt()
{
  test -n "$install_f" || install_f="$py_setup_f"
  git clone https://github.com/dotmpe/docopt-mpe.git $SRC_PREFIX/docopt-mpe
  ( cd $SRC_PREFIX/docopt-mpe \
      && git checkout 0.6.x \
      && $pref python ./setup.py install $install_f )
}

install_git_versioning()
{
  git clone https://github.com/dotmpe/git-versioning.git $SRC_PREFIX/git-versioning
  ( cd $SRC_PREFIX/git-versioning && ./configure.sh $PREFIX && ENV=production ./install.sh )
}

install_git_lfs()
{
  curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash
  $sudo apt-get install git-lfs
}

install_mkdoc()
{
  test -n "$MKDOC_BRANCH" || MKDOC_BRANCH=master
  stderr "Installing mkdoc ($MKDOC_BRANCH)"
  (
    cd $SRC_PREFIX
    test -e mkdoc ||
      git clone https://github.com/dotmpe/mkdoc.git
    cd mkdoc
    git checkout $MKDOC_BRANCH
    ./configure $PREFIX && ./install.sh
  )
  rm Makefile || printf ""
  ln -s $PREFIX/share/mkdoc/Mkdoc-full.mk Makefile
}

install_pylib()
{
  # for travis container build:
  pylibdir=$HOME/.local/lib/python2.7/site-packages
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
  test -n "$global" || {
    test -n "$sudo" && global=1 || global=0
  }

  test $global -eq 1 && {

    test -d /usr/local/lib/python2.7/site-packages/redo \
      || {

        $pref git clone https://github.com/apenwarr/redo.git \
            /usr/local/lib/python2.7/site-packages/redo || return 1
      }

    test -h /usr/local/bin/redo \
      || {

        $pref ln -s /usr/local/lib/python2.7/site-packages/redo/redo \
            /usr/local/bin/redo || return 1
      }

  } || {

    which basher 2>/dev/null >&2 && {

      basher install apenwarr/redo ||
          stderr "install apenwarr/redo" $?

    } ||

      stderr "Need basher to install apenwarr/redo locally" 1
  }
}

install_git_lfs()
{
  # XXX: for debian only, and requires sudo
  test -n "$sudo" || {
    stderr "sudo required for GIT lfs"
    return 1
  }
  curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash
  $pref apt-get install git-lfs
  # TODO: must be in repo. git lfs install
}

install_script()
{
  cwd=$(pwd)
  test -e $HOME/bin || ln -s $cwd $HOME/bin
}


main_entry()
{
  test -n "$1" || set -- all
  main_load

  case "$1" in all|project|test|git )
      git --version >/dev/null ||
        stderr "Sorry, GIT is a pre-requisite" 1
    ;; esac

  case "$1" in pip|python )
      which pip >/dev/null || {
        cd /tmp/ && wget https://bootstrap.pypa.io/get-pip.py && python get-pip.py; }
      $pref pip install -U $pip_flags appdirs packaging setuptools
      $pref pip install -U $pip_flags objectpath ruamel.yaml
      $pref pip install -U $pip_flags -r requirements.txt
      $pref pip install -U $pip_flags -r test-requirements.txt
    ;; esac

  case "$1" in all|build|test|sh-test|bats )
      test -x "$(which bats)" || { install_bats || return $?; }
      PATH=$PATH:$PREFIX/bin bats --version ||
        stderr "BATS install to $PREFIX failed" 1
    ;; esac

  case "$1" in php|composer )
      test -x "$(which composer)" \
        || install_composer || return $?
    ;; esac

  case "$1" in dev|git|git-lfs )
      git lfs || { install_git_lfs || return $?; }
    ;; esac

  case "$1" in dev|build|check|test|git-versioning )
      test -x "$(which git-versioning)" || {
        install_git_versioning || return $?; }
    ;; esac

  case "$1" in all|python|project|docopt )
      # Using import seems more robust than scanning pip list
      python -c 'import docopt' || { install_docopt || return $?; }
    ;; esac

  case "$1" in all|basher|test )
      test -d ~/.basher ||
        git clone https://github.com/basherpm/basher.git ~/.basher/
    ;; esac

  case "$1" in all|mkdoc)
      test -e Makefile || \
        install_mkdoc || return $?
    ;; esac

  case "$1" in all|pylib)
      install_pylib || return $?
    ;; esac

  case "$1" in all|script)
      install_script || return $?
    ;; esac

  case "$1" in npm|redmine|tasks)
      npm install -g redmine-cli || return $?
    ;; esac

  case "$1" in all|project|git|git-lfs )
      # TODO: install_git_lfs
    ;; esac

  case "$1" in redo )
      # TODO: fix for other python versions
      install_apenwarr_redo || return $?
    ;; esac

  case "$1" in travis|test )
      test -x "$(which gem)" ||
        stderr "ruby/gemfiles required" 1
      ruby -v
      gem --version
      test -x "$(which travis)" ||
    	${sudo} gem install travis -v 1.8.6 --no-rdoc --no-ri
    ;; esac

  stderr "OK. All pre-requisites for '$1' checked"
}

main_load()
{
  #test -x "$(which tput)" && ...
  log_pref="[install-dependencies] "
  stderr "Loaded"
}


{
  test "$(basename "$0")" = "install-dependencies.sh" ||
  test "$(basename "$0")" = "bash" ||
    stderr "0: '$0' *: $*" 1
} && {
  test -n "$1" -o "$1" = "-" || set -- all
  while test -n "$1"
  do
    main_entry "$1" || exit $?
    shift
  done
} || printf ""

# Id: script-mpe/0 install-dependencies.sh
