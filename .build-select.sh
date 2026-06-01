#!/usr/bin/env bash

us_debuglog () { false; }

case "${XREDO_TARGET}" in

( @config )
    >&2 ./configure.bash.build &&
    redo-ifchange ./configure.bash.build
  ;;


( @diag | @test )
    case $REDO_TARGET in
    ( @diag )
        declare -n user_script='user_basedir_diag[$uc_dirnum]'
      ;;
    ( @test )
        redo-ifdone @env
        declare -n user_script='user_basedir_test[$uc_dirnum]'
      ;;
    esac
    EWD=$REDO_BASE
    . .meta/config/us.bash
    . /var/local/statusdir/basedir,user.data.bash
    declare -n uc_dirnum='uc_basedir_pathid["$EWD"]'
    [[ "${user_script:+set}" ]] &&
    . <(echo "${user_script}") &&
    redo-always
  ;;

( @env )
    redo-ifdone @config
    . user-script.us-build.bash
    : "${REDO_TARGET:1}"
    . <(generate_self_build_recipe ${_}.bash)
  ;;

( * )
    redo-ifdone @env &&
    . ./env.bash || return

    return ${_E_next:-196}

esac
