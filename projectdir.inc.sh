#!/bin/sh


# Init Bg service
pd_meta_bg_setup()
{
  test -n "$no_background" && {
    note "Forcing foreground/cleaning up background"
    test ! -e "$sock" || pd__meta exit \
      || error "Exiting old" $?
  } || {
    test ! -e "$sock" || error "pd meta bg already running" 1
    pd__meta &
    while test ! -e $sock
    do note "Waiting for server.." ; sleep 1 ; done
    info "Backgrounded pd-meta for $(pwd)/projects.yaml (PID $!)"
  }
}

# Close Bg service
pd_meta_bg_teardown()
{
  test ! -e "$sock" || {
    pd__meta exit
    while test -e $sock
    do note "Waiting for background shutdown.." ; sleep 1 ; done
    info "Closed background metadata server"
    test -z "$no_background" || warn "no-background on while sock existed"
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

        pd__meta -q clean-mode $1 tracked || {

          pd__meta -q clean-mode $1 excluded \
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
    pd__meta -sq enabled $1 || {
      note "To be disabled: $1"
    }
  } || {
    pd__meta -sq enabled $1 || return 0
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



