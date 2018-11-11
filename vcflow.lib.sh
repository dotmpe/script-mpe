#!/bin/sh

# VCFlow - Generic version control up-/downstream workflows and checks


# Set default vars
vcflow_lib_load()
{
  test -n "$VCFLOW_DOC_EXTS" || VCFLOW_DOC_EXTS=".tab .txt"
  test -n "$vcflow_feature_re" || vcflow_feature_re='^feature[s]?/.*'
  test -n "$vcflow_devline_re" || vcflow_devline_re='^r([0-9])\.([0-9])'
  # Try to init lib
  test -n "$scm" || { vc_getscm || return 0; }
}


# Start env session for any gitflow file basename
vcflow_file_default() # Basename
{
  test -n "$1" || { shift ; set -- ${scm}flow ; }
  test -e "$1" || {
    for base in ./ ./. ./.local/ config/
    do
      for ext in "" $VCFLOW_DOC_EXTS
      do
        test -e $base$1$ext || continue
        note "Found vcflow doc for '$1'"
        set -- $base$1$ext; break
      done
    done
  }
  export vcflow="$1"
}

# Set vcflow env and check that doc file exists
vcflow_lib_set_local()
{
  vcflow_file_default "$1"
  test -e "$vcflow" || { warn "No ${scm}flow doc ($1)" ; return 1 ; }
}

# List branches either an down- or upstream for given Up-Or-Down branch
vcflow_read_related() # Flow Up-Or-Down
{
  test -n "$vcflow" || {
    vcflow_lib_set_local "$1" || return
  }
  test -n "$2" || error "Related Up-Or-Down branch name expected" 1
  read_nix_style_file "$vcflow" | while read -r upstream downstream isfeature
    do
        {
          test "$upstream" = "$2" || fnmatch "*/$2" "$upstream"
        } && {
          echo "$downstream"
        }
        {
          test "$downstream" = "$2" || fnmatch "*/$2" "$downstream"
        } && {
          echo "$upstream"
        }
        continue
    done
}

vcflow_has_upstream() # BRANCH
{
  grep -qE "^[^\ ]+\ $1($| )" "$vcflow"
}

gitflow_fork_feature() # BRANCH MSG
{
  echo "$(vc_branch) $1 true" >> "$vcflow"
  git add "$vcflow" && git commit -m "$2" && git checkout -b "$1"
}

gitflow_foreach_downstream()
{
  test -z "$4" || error "foreach-downstream: surplus argument(s) '$4'" 1
  test -n "$2" || set -- "$1" "echo \$downstream" "$3"
  test -n "$1" || set -- gitflow.tab "$2" "$3"
  test -e "$1" || error "foreach-downstream: missing gitflow file ($1)" 1
  test -n "$3" || set -- "$1" "$2" "$(git rev-parse --abbrev-ref HEAD)"
  info "foreach-downstream: reading downstream for '$3' from '$1'"
  read_nix_style_file "$1" | while read -r upstream downstream isfeature
  do
    test "$upstream" = "$3" || continue
    eval "$2" || error "Command evaluation failed: ($?) '$2'" 1
  done
}

gitflow_check_local_branches()
{
  test -z "$2" || error "surplus argument(s) '$2'" 1
  vcflow_lib_set_local "$1" || return
  note "Checking branches in '$vcflow'"
  git_branches | while read -r branch
  do
    grep -qF "$branch" "$vcflow" && stderr ok "Found '$branch'" || {
      echo "check-local-branches:$branch" >>$failed
      warn "Missing entry for '$branch'"
    }
  done
  test -s "$failed" || stderr ok "Checked branches in '$vcflow'"
}

gitflow_clean_local_features()
{
  test -n "$dry_run" || dry_run=1
  git_branches | grep features | while read -r fb
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
