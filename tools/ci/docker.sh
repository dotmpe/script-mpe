#!/bin/sh

set -e

scriptname=tools/ci/docker

subcmd="$1"
shift
type error >/dev/null 2>&1 || { . ./util.sh; }

test -n "$subcmd" || error "argument expected" 1


test -n "$cname" || {
  cname="$(hostname -s | tr 'A-Z.-' 'a-z__')"-sandbox
  test -z "$tag" || {
    cname=$cname-$tag
  }
}

note "$@"

case "$subcmd" in

  treebox-test )
      $0 treebox-pd test || r=$?
      ;;

  treebox-check )
      $0 treebox-pd check || r=$?
      ;;

  treebox-pd )
      PWD="$(pwd -P)"
      docker run \
        -u $(whoami) \
        -v $PWD:/opt/script-mpe \
        dotmpe/sandbox \
        bash -c "echo 'Container started..';cd /opt/script-mpe; ./projectdir.sh $@; exit \$?"
      ;;

  sandbox-check )
    $0 sandbox-init && {
      $0 docker-exec "PATH=/opt/sandbox:\$HOME/bin:\$PATH ; PYTHONPATH=\$HOME/lib/py:\$PYTHONPATH ; cd /opt/sandbox ; ./projectdir.sh check ; exit \$?" \
        || r=$?
    }
    $0 sandbox-clean && info "container removed"  || r=$?
    ;;

  sandbox-bats )
    $0 sandbox-init && {
      $0 docker-exec "PATH=/opt/sandbox:\$HOME/bin:\$PATH ; PYTHONPATH=\$HOME/lib/py:\$PYTHONPATH ; cd /opt/sandbox ; echo \$PATH; ( ./test/*-spec.bats | ./bats-color.sh ); exit \$?" \
        || r=$?
    }
    $0 sandbox-clean && info "container removed"  || r=$?
    ;;

  sandbox-test )
    $0 sandbox-init && {
      $0 docker-exec "PATH=/opt/sandbox:\$HOME/bin:\$PATH ; PYTHONPATH=\$HOME/lib/py:\$PYTHONPATH ; cd /opt/sandbox ; echo \$PATH; ./projectdir.sh test ; exit \$?"
    }
    $0 sandbox-clean && info "container removed" || r=$?
    ;;

  sandbox-init )
      docker run \
        -td \
        -u $(whoami) \
        -v $PWD:/opt/sandbox \
        -e PD_SKIP=1 \
        --name $cname \
        dotmpe/sandbox \
        bash \
          || r=$? ;;
  sandbox-clean )
        docker rm -f $cname \
          || r=$? ;;

  docker-exec )
      test -n "$dckr_exec_f" || dckr_exec_f="-t"
      docker exec $dckr_exec_f $cname \
        bash -c "$@" \
          || r=$? ;;

  docker-exec-ti )
    test -n "$dckr_exec_f" || export dckr_exec_f="-ti"
    $0 docker-exec "$@" || r=$? ;;

  docker-exec-ti-user )
    test -n "$dckr_exec_f" || export dckr_exec_f="-ti -u $dckr_user"
    $0 docker-exec "whoami; $@" || r=$? ;;

  git-versioning-install )
    $0 docker-exec-ti \
      'test -x "$(which git-versioning)" || ( mkdir -vp $HOME/build && git clone https://github.com/dotmpe/git-versioning.git $HOME/build/ && cd $HOME/build/git-versioning && make install )' \
          || r=$? ;;

  git-versioning-upgrade )
    $0 docker-exec-ti \
      'cd $HOME/build/git-versioning && git checkout master && git pull && make uninstall && make install' \
          || r=$? ;;

  * )
      error "No $scriptname subcmd '$subcmd'" 1
      ;;
esac

test -z "$r" || {
  warn "$subcmd failed $r" $r
}

