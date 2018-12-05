#!/bin/sh


# set-local, and echo local path-name for vcflow doc
htd_vcflow_doc()
{
  vcflow_lib_set_local "$1" || return
  echo "$vcflow"
}

#htd_vcflow_check_doc()
#{
#  test -z "$2" || error "surplus argument(s) '$2'" 1
#  test -n "$1" || set -- gitflow.tab
#  test -e "$1" || error "missing gitflow file ($1)" 1
#  note "Reading from '$1'"
#  # Finally check if local branches are listed in gitflow.tab
#  for branch in $(vc_branches)
#  do
#    grep -qF "$branch" "$1" ||
#      error "Missing gitflow for '$branch'"
#  done
#}

htd_vcflow_check_doc()
{
  test -n "$failed" || error failed 1
  test -z "$2" || error surplus-args 2
  vcflow_lib_set_local "$1" || return
  exec 6>$failed
  vc.sh list-all-branches | while read -r branch
  do
    match_grep_pattern_test "$branch" || return 12
    grep -qE "\<$p_\>" $vcflow || failed "$vcflow: expected '$branch'"
  done
  exec 6<&-
  test -s "$failed" && {
    stderr failed "missing some branch references in '$vcflow'"
  } || {
    rm "$failed"
    stderr ok "checked for and found references for all branches in '$vcflow'"
  }
}

htd_vcflow_status()
{
  note "TODO: see gitflow-check-doc"
  return
  defs gitflow.txt | \
    tree_to_table  | \
    while read -r base branch
    do
      git cherry $base $branch | wc -l
    done
}

# With flowname, given up/down summary for each up and downstream.
# Without flowname, compare to every branch.
htd_vcflow_summary() # Flow Branch
{
  test -n "$scm" || {
    vc_getscm "." || return
  }
  test -n "$2" || set -- "$1" "$(vc_branch)"
  test -z "$3" || error 2-args 1

  cnt=$(vc_branches | count_lines)
  test $cnt -gt 1 || error "Only one branch in this repo" 0

  # Set first arg if default vcflow doc is found
  test -n "$1" || {
    vcflow_lib_set_local "" 2>/dev/null && set -- "${scm}flow" "$2" 0
  }

  # Read either related branches from doc, or list all local
  {
    test -n "$1" -a \( "$1" != "all" \) && {
      vcflow_lib_set_local "$1" || return
      grep -q "\\<$2\\>" "$vcflow" || error "No flows for $2 in $vcflow" 1
      std_info "Summary for $2 ($1)"
      test -n "$3" || set -- "$1" "$2" 1
      vcflow_read_related "" "$2"
    } || {
      note "No ${scm}flow doc, listing all branches"
      vc_branches all || return
    }
  } | while read -r branch
  do
    test "$branch" != "$2" -a -n "$branch" || continue

    # Skip non-local, warn about missing vcflow branch
    vc_exists_local "$branch" || {
      test -n "$1" ||
        debug "Skipping remote '$branch'" &&
        std_info "Missing local '$branch' for doc '$1'"
      continue
    }

    htd_vcflow_summary_up_down "$2" "$branch" || true
  done
}

# Give commits each branch is out of sync, return 1, 2 or 3 if diverged; with
# new commits on up, down or both
htd_vcflow_summary_up_down() # Up Down
{
  test -n "$2" || set -- "$1" "$(git rev-parse --abbrev-ref HEAD)"
  new_at_up=$(echo $(git log --oneline $2..$1 | wc -l))
  new_at_down=$(echo $(git log --oneline $1..$2 | wc -l))

  test $new_at_down -eq 0 -a $new_at_up -eq 0 || {
    test $new_at_up -eq 0 && _up=- || _up=+$new_at_up
    test $new_at_down -eq 0 && _down=- || _down=+$new_at_down
    stderr warn "diverged: $1 ($_up) .. $2 ($_down)"
  }

  test $new_at_down -eq 0 -a $new_at_up -eq 0 && return
  test $new_at_down -eq 0 -a $new_at_up -ne 0 && return 2
  test $new_at_down -ne 0 -a $new_at_up -eq 0 && return 1
  test $new_at_down -ne 0 -a $new_at_up -ne 0 && return 3
}

htd_vcflow_check()
{
  test -z "$2" || error "surplus argument(s) '$2'" 1
  vcflow_lib_set_local "$1" || return
  note "Reading from '$vcflow'"
  test "$scm" = "git" || error "vcflow for GIT only" 1
  read_nix_style_file "$vcflow" | while read -r upstream downstream isfeature
  do
    test -n "$upstream" -a -n "$downstream" || {
      warn "Incomplete line '$upstream $downstream $isfeature'"
      continue
    }
    test -n "$upstream" || error "Missing upstream $downstream"
    test -n "$downstream" || error "Missing downstream $upstream"
    test -n "$isfeature" || isfeature=true

    #git_local_branch "$upstream" || {
    #  non_branch_err="Upstream not a local branch at gitflow:"
    #  warn "$non_branch_err '$upstream $downstream $isfeature'" &&
    #    continue
    #}

    #git_local_branch "$downstream" || {
    #  # Note: normally ignore missing downstreams features etc.
    #  non_branch_err="Downstream not a local branch at gitflow:"
    #  std_info "$non_branch_err '$upstream $downstream $isfeature'" &&
    #    continue
    #}

    htd_vcflow_summary "$upstream" "$downstream" "$isfeature"
    # Find last sync point
    m="$(git merge-base "$upstream" "$downstream")"
    test "$m" = "$(git rev-parse $upstream)" -a "$m" = "$(git rev-parse $downstream)" && {
      stderr ok "$upstream - $downstream"
    } || {
      test $new_at_up -eq 0 && _up=- || _up=+$new_at_up
      test $new_at_down -eq 0 && _down=- || _down=+$new_at_down
      stderr warn "diverged: $upstream ($_up) .. $downstream ($_down)"
    }

    test $new_at_down -eq 0 && {
      trueish "$isfeature" && {
        note "downstream '$downstream' has no commits over '$upstream' and could be removed"
      } || true
    } ||
      note "$new_at_down commits '$upstream' <- '$downstream' "

    test $new_at_up -eq 0 ||
      note "$new_at_up commits '$upstream' -> '$downstream' "

  done
}

htd_vcflow_list_features()
{
  vc_branches all | grep -E $vcflow_feature_re
}

htd_vcflow_check_devline()
{
  local branch=$(vc_branch)
  echo "$branch" | grep -qE $vcflow_devline_re || {
      warn "Not on development branch: $branch" 1
  }
  vcflow_file_default
  vcflow_has_upstream "$branch" ||
      warn "No upstream for development branche '$branch'" 1
}

htd_vcflow_new_feature() # Id Msg...
{
  htd_vcflow_check_devline || return
  local id= sid= feature_id=
  lower=1 mksid "$1" ; id="$1" ; shift ; feature_id="$sid"
  vc_exists "feature/$sid" && {
      warn "Branch for '$id' already exists 'feature/$sid'" 1
  }
  note "Branching 'feature/$sid'..."
  test -n "$1" || set -- "Starting feature '$id' (feature/$feature_id)"
  gitflow_fork_feature "feature/$feature_id" "$*"
}

gitflow_update_downstream() # [gitflow.tab] [<recurse>=0] <abort-clean>=1] [<git-action>=merge]
{
  test -z "$6" || error "surplus argument(s) '$6'" 1
  test -n "$1" || { set -- "$(htd_vcflow_doc)" "$3" "$4" "$5" || return ; }
  test -e "$1" || error "missing gitflow file ($1)" 1
  test -n "$recurse" || recurse=0
  test -n "$2" || set -- "$1" "$recurse" "$3" "$4"
  test -n "$abort_clean" || abort_clean=1
  test -n "$3" || set -- "$1" "$2" "$abort_clean" "$4"
  test -n "$git_act" || git_act=merge
  test -n "$4" || set -- "$1" "$2" "$3" "$git_act"

  local current_branch="$(git rev-parse --abbrev-ref HEAD)"
  trueish "$2" &&
    note "Recursive $4 for ALL downstreams at '$current_branch'"
  test ! -e sugarcrm/ || git submodule deinit sugarcrm/
  gitflow_foreach_downstream "$1" "" "$current_branch" |
    while read -r downstream
  do
    note "$4'ing downstream for $current_branch: $downstream"
    (
      git_checkout "$downstream" "" || return 1
      git $4 $current_branch || return $?
      # Recursive call to downstreams of downstreams, etc.
      trueish "$2" && gitflow_update_downstream "$1" || return 0
    ) && stderr ok "$current_branch -> $downstream" || {
      trueish "$3" && {
        note "Cleaning up failed $4..."
        git $4 --abort
      } || git status
      error "Failed $4 at $current_branch -> $downstream" 1
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

  test ! -e .gitmodules || git submodule deinit --all

  git show-ref --heads | cut -c53- | while read -r branch
  do
    vc_rt_def_branch "$branch" "$1" || {
      warn "No remote-ref at $1 for $branch, skipped"
      continue
    }
    std_info "$3'ing $branch from $1..."
    (
       git_checkout "$branch" "$1" || return $?
       git fetch "$1" "$branch" || return $?
       git $3 "$1/$branch" || return $?
    ) && stderr ok "$3'd local branch '$branch'" || {
      trueish "$2" && {
        std_info "Cleaning up failed $1..."
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
