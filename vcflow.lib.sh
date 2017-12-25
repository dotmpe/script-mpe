#!/bin/sh

# VCFlow - Generic version control up-/downstream workflows and checks


# Set default vars
vcflow_lib_load()
{
  test -n "$scm" || { vc_getscm || return 0; }
  test -n "$DOC_EXTS" || DOC_EXTS=".tab .txt"
}

# Start env session for specific gitflow file
vcflow_file_default()
{
  test -n "$1" || { shift ; set -- ${scm}flow ; }
  test -e "$1" || {
    for base in ./ ./. config/
    do
      for ext in "" $DOC_EXTS
      do
        test -e $base$1$ext || continue
        set -- $base$1$ext; break
      done
    done
  }
  test -e $1 || error no-${scm}flow-doc 2
  export vcflow="$1"
}

vcflow_lib_set_local()
{
  vcflow_file_default
}

htd_vcflow_doc()
{
  echo $vcflow
}

htd_vcflow_check_doc()
{
  test -n "$failed" || error failed 1
  test -z "$2" || error surplus-args 2
  set -- "$(htd_vcflow_doc "$1")"
  exec 6>$failed
  vc.sh list-all-branches | while read branch
  do
    match_grep_pattern_test "$branch" || return 12
    grep -qE "\<$p_\>" $1 || failed "$1: expected '$branch'"
  done
  exec 6<&-
  test -s "$failed" && {
    stderr failed "missing some branch references in '$1'"
  } || {
    rm "$failed"
    stderr ok "checked for and found references for all branches in '$1'"
  }
}

htd_vcflow_status()
{
  note "TODO: see gitflow-check-doc"
  defs gitflow.txt | \
    tree_to_table  | \
    while read base branch
    do
      git cherry $base $branch | wc -l
    done
}

gitflow_foreach_downstream()
{
  test -z "$4" || error "foreach-downstream: surplus argument(s) '$4'" 1
  test -n "$2" || set "$1" "echo \$downstream" "$3"
  test -n "$1" || set -- gitflow.tab "$2" "$3"
  test -e "$1" || error "foreach-downstream: missing gitflow file" 1
  test -n "$3" || set -- "$1" "$2" "$(git rev-parse --abbrev-ref HEAD)"
  info "foreach-downstream: reading downstream for '$3' from '$1'"
  read_nix_style_file "$1" | while read upstream downstream isfeature
  do
    test "$upstream" = "$3" || continue
    eval "$2" || error "Command evaluation failed: ($?) '$2'" 1
  done
}

gitflow_check_local_branches()
{
  test -z "$3" || error "surplus argument(s) '$3'" 1
  test -n "$2" || set -- "$1" gitflow.tab
  test -e "$2" || error "missing gitflow file" 1
  note "Checking branches in '$2'"
  git_branches | while read branch
  do
    grep -qF "$branch" "$2" && stderr ok "Found '$branch'" || {
      echo "check-local-branches:$branch" >>$failed
      warn "Missing entry for '$branch'"
    }
  done
  test -s "$failed" || stderr ok "Checked branches in '$2'"
}

gitflow_clean_local_features()
{
  test -n "$dry_run" || dry_run=1
  git_branches | grep features | while read fb
  do
    git show-ref --verify -q "refs/remotes/origin/$fb" || {
      warn "No branch '$fb'"
      continue
    }
    m=$( git merge-base origin/$fb $fb )
    test "$m" = "$(git rev-parse origin/$fb)" -o "$m" = "$(git rev-parse $fb)" && {
      trueish "$dry_run" && {
        note "OK, in sync '$fb' to be dropped locally"
      } || {
        git branch -d "$fb"
      }
    } || {
      info "Local changes on '$fb'"
    }
  done
}

gitflow_check()
{
  test -z "$3" || error "surplus argument(s) '$3'" 1
  test -n "$2" || set -- "$1" gitflow.tab
  test -e "$2" || error "missing gitflow file" 1
  note "Reading from '$2'"
  read_nix_style_file "$2" | while read upstream downstream isfeature
  do
    test -n "$upstream" -a -n "$downstream" || continue
    test -n "$upstream" || error "Missing upstream $downstream"
    test -n "$downstream" || error "Missing downstream $upstream"
    test -n "$isfeature" || isfeature=true

    git_local_branch "$upstream" || {
      non_branch_err="Upstream not a local branch at gitflow:"
      warn "$non_branch_err '$upstream $downstream $isfeature'" &&
        continue
    }

    git_local_branch "$downstream" || {
      # Note: normally ignore missing downstreams features etc.
      non_branch_err="Downstream not a local branch at gitflow:"
      info "$non_branch_err '$upstream $downstream $isfeature'" &&
        continue
    }

    new_at_up=$(echo $(git log --oneline $downstream..$upstream | wc -l))
    new_at_down=$(echo $(git log --oneline $upstream..$downstream | wc -l))

    test $new_at_down = 0 -o $new_at_up = 0 || {
      m="$(git merge-base $upstream $downstream)"
      test "$m" = "$(git rev-parse $upstream)" -o "$m" = "$(git rev-parse $downstream)" && {
        stderr ok "$upstream - $downstream"
      } || {
        stderr warn "diverged: $upstream .. $downstream"
      }
    }

    test $new_at_down -eq 0 && {
      trueish "$isfeature" && {
        note "downstream '$downstream' has no commits and could be removed"
      } || true
    } ||
      note "$new_at_down commits '$upstream' <- '$downstream' "

    test $new_at_up -eq 0 ||
      note "$new_at_up commits '$upstream' -> '$downstream' "

  done
  # Finally check if local branches are listed in gitflow.tab
  for branch in $(git_branches)
  do
    grep -qF "$branch" "$2" ||
      error "Missing gitflow for '$branch'"
  done
}

gitflow_update_downstream() # [gitflow.tab] [<recurse>=0] <abort-clean>=1] [<git-action>=merge]
{
  test -z "$6" || error "surplus argument(s) '$6'" 1
  test -n "$2" || set -- "$1" gitflow.tab "$3" "$4" "$5"
  test -e "$2" || error "missing gitflow file" 1
  test -n "$recurse" || recurse=0
  test -n "$3" || set -- "$1" "$2" "$recurse" "$4" "$5"
  test -n "$abort_clean" || abort_clean=1
  test -n "$4" || set -- "$1" "$2" "$3" "$abort_clean" "$5"
  test -n "$git_act" || git_act=merge
  test -n "$5" || set -- "$1" "$2" "$3" "$4" "$git_act"

  local current_branch="$(git rev-parse --abbrev-ref HEAD)"
  trueish "$3" &&
    note "Recursive $5 for ALL downstreams at '$current_branch'"
  test ! -e sugarcrm/ || git submodule deinit sugarcrm/
  gitflow_foreach_downstream "$2" "" "$current_branch" |
    while read downstream
  do
    note "$5'ing downstream for $current_branch: $downstream"
    (
      git_checkout "$downstream" "" || return 1
      git $5 $current_branch || return $?
      # Recursive call to downstreams of downstreams, etc.
      trueish "$3" && gitflow_update_downstream "$2" || return 0
    ) && stderr ok "$current_branch -> $downstream" || {
      trueish "$4" && {
        note "Cleaning up failed $5..."
        git $5 --abort
      } || git status
      error "Failed $5 at $current_branch -> $downstream" 1
    }
  done

  git status --porcelain | grep -q '^\(U.\)\|\(.U\)' && {
    warn "Unresolved issues, can't return to $current_branch" 1
  } || {
    git checkout $current_branch
    test ! -e sugarcrm/ || git submodule init sugarcrm/
  }
}

gitflow_update_local()
{
  test -z "$4" || error "surplus argument(s) '$4'" 1
  test -n "$1" || set -- "$vc_rt_def" "$2" "$3"
  test -n "$abort_clean" || abort_clean=1
  test -n "$2" || set -- "$1" "$abort_clean" "$3"
  test -n "$git_act" || git_act=merge
  test -n "$3" || set -- "$1" "$2" "$git_act"

  local current_branch="$(git rev-parse --abbrev-ref HEAD)"
  test ! -e sugarcrm/ || git submodule deinit sugarcrm/
  git show-ref --heads | cut -c53- | while read branch
  do
    vc_rt_def_branch "$branch" "$1" || {
      warn "No remote-ref at $1 for $branch, skipped"
      continue
    }
    info "$3'ing $branch from $1..."
    (
       git_checkout "$branch" "$1" || return $?
       git fetch "$1" "$branch" || return $?
       git $3 "$1/$branch" || return $?
    ) && stderr ok "$3'd local branch '$branch'" || {
      trueish "$2" && {
        info "Cleaning up failed $1..."
        git $3 --abort
      } || git status
      error "Failed auto-update for local branch '$branch'" 1
    }
  done

  git status --porcelain | grep -q '^\(U.\)\|\(.U\)' && {
    warn "Unresolved issues, can't return to $current_branch" 1
  } || {
    git checkout $current_branch
    test ! -e sugarcrm/ || git submodule init sugarcrm/
  }
}
