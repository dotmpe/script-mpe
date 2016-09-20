#!/usr/bin/env bash

set -e

test -z "$Build_Debug" || set -x

test -z "$Build_Deps_Default_Paths" || {
  test -n "$SRC_PREFIX" || SRC_PREFIX=$HOME/build
  test -n "$PREFIX" || PREFIX=$HOME/.local
}

test -n "$sudo" || sudo=
test -z "$sudo" || pref="sudo $pref"
test -z "$dry_run" || pref="echo $pref"


test -n "$SRC_PREFIX" || {
  echo "Not sure where checkout"
  exit 1
}

test -n "$PREFIX" || {
  echo "Not sure where to install"
  exit 1
}

test -d $SRC_PREFIX || ${sudo} mkdir -vp $SRC_PREFIX
test -d $PREFIX || ${sudo} mkdir -vp $PREFIX


install_bats()
{
  echo "Installing bats"
  local pwd=$(pwd)
  test -n "$BATS_BRANCH" || BATS_BRANCH=master
  mkdir -vp $SRC_PREFIX
  cd $SRC_PREFIX
  test -n "$BATS_REPO" || BATS_REPO=https://github.com/dotmpe/bats.git
  test -n "$BATS_BRANCH" || BATS_BRANCH=master
  git clone $BATS_REPO bats || return $?
  cd bats
  git checkout $BATS_BRANCH
  ${pref} ./install.sh $PREFIX
  cd $pwd
}

install_git_versioning()
{
  git clone https://github.com/dotmpe/git-versioning.git $SRC_PREFIX/git-versioning
  ( cd $SRC_PREFIX/git-versioning && ./configure.sh $PREFIX && ENV=production ./install.sh )
}

install_docopt()
{
  test -n "$sudo" || install_f="--user"
  git clone https://github.com/dotmpe/docopt-mpe.git $SRC_PREFIX/docopt-mpe
  ( cd $SRC_PREFIX/docopt-mpe \
      && git checkout 0.6.x \
      && $pref python ./setup.py install $install_f )
}

install_mkdoc()
{
  echo "Installing mkdoc"
  pushd $SRC_PREFIX
  git clone https://github.com/dotmpe/mkdoc.git
  cd mkdoc
  git checkout devel
  PREFIX=~/usr/ ./configure && ./install.sh
  popd
  rm Makefile
  ln -s ~/usr/share/mkdoc/Mkdoc-full.mk Makefile
  #make
}

# expecting cwd to be ~/build/dotmpe/script-mpe/ but asking anyway

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
    echo ln -s $cwd script_mpe
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

      basher install apenwarr/redo
    } || {

      echo "Need basher to install apenwarr/redo locally" >&2
      return 1
    }
  }
}

install_git_lfs()
{
  # XXX: for debian only, and requires sudo
  test -n "$sudo" || {
    error "sudo required for GIT lfs"
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
  echo "install-script pwd=$cwd"
  echo "install-script bats=$(which bats)"
}


main_entry()
{
  test -n "$1" || set -- '-'

  case "$1" in '-'|project|git )
      git --version >/dev/null || {
        echo "Sorry, GIT is a pre-requisite"; exit 1; }
      which pip >/dev/null || {
        cd /tmp/ && wget https://bootstrap.pypa.io/get-pip.py && python get-pip.py; }
      pip install --user setuptools objectpath ruamel.yaml \
        || exit $?
    ;; esac

  case "$1" in '-'|build|test|sh-test|bats )
      test -x "$(which bats)" || { install_bats || return $?; }
    ;; esac

  case "$1" in '-'|dev|build|check|test|git-versioning )
      test -x "$(which git-versioning)" || {
        install_git_versioning || return $?; }
    ;; esac

  case "$1" in '-'|python|project|docopt)
      # Using import seems more robust than scanning pip list
      python -c 'import docopt' || { install_docopt || return $?; }
    ;; esac

  case "$1" in npm|redmine|tasks)
      npm install -g redmine-cli || return $?
    ;; esac

  case "$1" in '-'|redo )
      # TODO: fix for other python versions
      install_apenwarr_redo || return $?
    ;; esac

  case "$1" in -|mkdoc)
      install_mkdoc || return $?
    ;; esac

  case "$1" in -|pylib)
      install_pylib || return $?
    ;; esac

  case "$1" in -|script)
      install_script || return $?
    ;; esac

  case "$1" in '-'|project|git|git-lfs )
    ;; esac

  echo "OK. All pre-requisites for '$1' checked"
}

test "$(basename $0)" = "install-dependencies.sh" && {
  while test -n "$1"
  do
    main_entry "$1" || exit $?
    shift
  done
} || printf ""

# Id: script-mpe/0 install-dependencies.sh
