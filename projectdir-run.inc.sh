
# Execute external check/test/build scripts
# and track associated states

# allow leading semicolon
test ":" = "$(echo "$1" | cut -c1)" && {
  set -- "$(echo "$1" | cut -c2-)"
#} || {
#  set -- "sh:-c $1"
}


case "$1" in

  '*' | bats-specs )

      # Get path to bats libexec's
      bats_bin=$(which bats)
      while test -h "$bats_bin"; do bats_bin="$(realpath "$bats_bin")"; done

      local PREFIX="$(dirname "$(dirname "$bats_bin")")"
      # FIXME: still needed at travis?
      case "$(whoami)" in
        travis )
            export PATH=$PATH:$HOME/.local/libexec/
          ;;
        * )
            export PATH=$PATH:$PREFIX/libexec/
          ;;
      esac
      unset PREFIX

      local count=0 specs=0

      for x in ./test/*-spec.bats
      do
        local s=$(verbosity=0; bats-exec-test -c "$x" || {
          #pd_update_status bats/invalid=1;
          error "Bats source not ok: cannot load $x"
          echo $1:$x >&5
          continue
        })
        incr specs $s
        incr count
      done

      #pd_update_status bats/invalid=1

      status_key=bats
      states="bats/files=$count bats/tests=$specs"

      test $count -gt 0 \
        && {
          note "$specs specs, $count spec-files OK"
        } || {
          warn "No Bats specs found"; echo $1 >&6
        }
    ;;

  bats:* )
      status_key=bats
      local_target=$(echo $1 | cut -c 6-)
      export $(hostname -s | tr 'a-z.-' 'A-Z__')_SKIP=1
      {
        bats $local_target.bats || return $?
      } | bats-color.sh
    ;;

  bats )
      status_key=bats
      export $(hostname -s | tr 'a-z.-' 'A-Z__')_SKIP=1
      {
        verbosity=6 ./test/*-spec.bats || return $?
      } | bats-color.sh

      #for x in ./test/*-spec.bats;
      #do
      #  bats $x || echo bats:$x >&6
      #done
    ;;

  mk-test )
      status_key=make/test
      make test || return $?
    ;;

  make:* )
      status_key=make
      local_target=$(echo $1 | cut -c 6-)
      test -z "$local_target" || status_key=$status_key/$local_target
      make $local_target || return $?
    ;;

  npm | npm:* | npm-test )
      status_key=npm
      local_target=$(echo $1 | cut -c 5-)
      test -z "$local_target" || status_key=$status_key/$local_target
      npm $local_target || return $?
    ;;

  grunt-test | grunt | grunt:* )
      status_key=grunt
      local_target=$(echo $1 | cut -c 7-)
      test -z "$local_target" || status_key=$status_key/$local_target
      grunt $local_target || return $?
    ;;

  git-versioning | vchk )
      status_key=vchk
      git-versioning check >/dev/null 2>&1 || return $?
    ;;

  python:* )
      status_key=python
      local_target=$(echo $1 | cut -c 8-)
      test -z "$local_target" || status_key=$status_key/$local_target
      test $verbosity -gt 6 && {
        python $local_target || return $?
      } || {
        python $local_target >/dev/null 2>&1 || return $?
      }
    ;;

  sh:* )
      local cmd="$(echo "$1" | cut -c 4- | tr ':' ' ')"
      info "Using Sh '$cmd'"
      status_key=sh
      local_target=$(echo $1 | cut -c 4-)
      test -z "$local_target" || status_key=$status_key/$local_target
      sh -c "$cmd" || return $?
    ;;

  -* )
      # Ignore return
      # backup $failed, setup new and only be verbose about failures.
      #test ! -s "$failed" || cp $failed $failed.ignore

      . $scriptdir/$scriptname-run.inc.sh $(expr_substr ${1} 2 ${#1}) || noop

      #( failed=/tmp/pd-run-$(uuidgen) pd__run $(expr_substr ${1} 2 ${#1});
      #  clean_failed "*IGNORED* Failed targets:")
      #test ! -e $failed.ignore || mv $failed.ignore $failed
    ;;

  * )
      error "No such run ID $1" 1
    ;;

esac

