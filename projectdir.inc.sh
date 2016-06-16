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
    info "Backgrounded pd-meta for $pd (PID $!)"
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

pd_clean()
{
  (cd "$1"; git diff --quiet) || {
    dirty="$(cd "$1"; git diff --name-only)"
    return 1
  }

  test -n "$pd_meta_clean_mode" || pd_meta_clean_mode=untracked

  trueish "$choice_strict" \
    && pd_meta_clean_mode=excluded

  debug "Mode: $pd_meta_clean_mode"

  test "$pd_meta_clean_mode" = tracked || {

    #cruft="$(cd $1; vc__excluded)"

    test "$pd_meta_clean_mode" = excluded \
      && cruft="$(cd $1; vc__excluded)" \
      || cruft="$(cd $1; vc__unversioned_files)"
  }


  test -z "$cruft" || {
    trueish $choice_force && {
      ( cd "$1" ; git clean -dfx )
      warn "Force cleaned everything in $1"
    } || return 2
  }
}

# dir exist and is enabled checkout, or is not enabled
pd_check()
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

backup_if_comments()
{
  test -f "$1" || error "file expected: '$1'" 1
  grep -q '^\s*#' $1 && {
    test ! -e $1.comments || error "backup exists: '$1.comments'" 1
    cp $1 $1.comments
  } || noop
}


# Generate/install GIT hook scripts from env (loaded from package.yaml)

test -n "$GIT_HOOK_NAMES" || GIT_HOOK_NAMES="apply-patch commit-msg post-update pre-applypatch pre-commit pre-push pre-rebase prepare-commit-msg update"

generate_git_hooks()
{
  # Create default script from pd-check
  test -n "$package_pd_meta_git_hooks_pre_commit_script" || {
    package_pd_meta_git_hooks_pre_commit_script="set -e ; pd check $package_pd_meta_check"
  }

	for script in $GIT_HOOK_NAMES
	do
		t=$(eval echo \$package_pd_meta_git_hooks_$(echo $script|tr '-' '_'))
		test -n "$t" || continue
    test -e "$t" || {
      s=$(eval echo \$package_pd_meta_git_hooks_$(echo $script|tr '-' '_')_script)
      test -n "$s" || {
        echo "No default git $script script. "
        return
      }

      mkdir -vp $(dirname $t)
      echo "$s" >$t
      chmod +x $t
      echo "Generated $script GIT commit hook"
    }
  done
}

install_git_hooks()
{
	for script in $GIT_HOOK_NAMES
	do
		t=$(eval echo \$package_pd_meta_git_hooks_$(echo $script|tr '-' '_'))
		test -n "$t" || continue
		l=.git/hooks/$script
		test ! -e "$l" || {
			test -h $l && {
				test "$(readlink $l)" = "../../$t" && continue || {
					rm $l
				}
			} ||	{
				echo "Git hook exists and is not a symlink: $l"
				continue
			}
		}
		( cd .git/hooks; ln -s ../../$t $script )
    echo "Installed GIT hook symlink: $script -> $t"
	done
}


pd_regenerate()
{
  debug "pd-regenerate pwd=$(pwd) 1=$1"

  # Regenerate .git/info/exclude
  vc__regenerate "$1" || echo "pd-regenerate:$1" 1>&3

  test ! -e .package.sh || . .package.sh

  # Regenerate from package.yaml: GIT hooks
  env | grep -qv '^package_pd_meta_git_' && {
    generate_git_hooks && install_git_hooks \
      || echo "pd-regenerate:git-hooks:$1" 1>&3
  }

}


pd_list_upstream()
{
  test -n "$prefix"
  pd__meta -s list-upstream "$prefix" \
    | while read remote branch
  do
    test "$branch" != "*" && {
      echo $remote $branch
    } || {
      for branch in $(vc__list_local_branches "$prefix")
      do
        echo $remote $branch
      done
    }
  done
}
