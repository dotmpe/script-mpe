#!/bin/sh



pd_meta_bg_setup()
{
  test -n "$no_background" && {
    note "Forcing foreground/cleaning up background"
    test ! -e "/tmp/pd-serv.sock" || projectdir-meta exit \
      || error "Exiting old" $?
  } || {
    test ! -e "/tmp/pd-serv.sock" || error "pd meta bg already running" 1
    projectdir-meta --background &
    while test ! -e /tmp/pd-serv.sock
    do note "Waiting for server.." ; sleep 1 ; done
    info "Backgrounded pd-meta for $(pwd)/projects.yaml (PID $!)"
  }
}
pd_meta_bg_teardown()
{
  test -n "$no_background" || {
    projectdir-meta exit
    info "Closed background metadata server"
  }
}

vc_clean()
{
  dirty="$(cd $1; git diff --quiet || echo 1)"
  test -n "$dirty" && {
    return 1

  } || {

    test -n "$choice_strict" \
      && cruft="$(cd $1; vc excluded)" \
      || {

        projectdir-meta -q clean-mode $1 tracked || {

          projectdir-meta -q clean-mode $1 excluded \
            && cruft="$(cd $1; vc excluded)" \
            || cruft="$(cd $1; vc unversioned-files)"
        }

      }

    test -z "$cruft" || {
      return 2
    }
  }
}

# dir exist and is enabled checkout, or is not enabled
vc_check()
{
  test -d "$1" && {
    test -e "$1/.git" || {
      note "Not a checkout: $1"
      return 1
    }
    projectdir-meta -sq enabled $1 || {
      note "To be disabled: $1"
    }
  } || {
    projectdir-meta -sq enabled $1 || return
    note "Missing checkout: $1"
    return 1
  }
}

vc_list_local_branches()
{
  local pwd=$(pwd)
  test -z "$1" || cd $1
  git branch -l | sed -E 's/\*|[[:space:]]//g'
  test -z "$1" || cd $pwd
}

backup_if_comments()
{
  test -f "$1" || error "file expected: '$1'" 1
  grep -q '^\s*#' $1 && {
    test ! -e $1.comments || error "backup exists: '$1.comments'" 1
    cp $1 $1.comments
  } || noop

}



