
htd_man_1__git='

  info
    Compile some info on checkouts (remote names and URLs) in $PROJECTS.

  find <user>/<repo>
    Look in all /srv/scm-git for repo.

  req|require <user>/<repo> [Check-Branch]
    See that checkout for repo is available, print path. With branch or other
    version check version of checkout as well.

  get <user>/<repo> [Version]
    Create or upate repo at /srv/scm-git, then make checkout at $VND_GH_SRC.
    Link that to $PROJECT_DIR.

  get-env [ENV] <user>/<repo> [Version]
    Make a reference checkout in a new subdir of $SRC_LOCAL and set it to commit
    or Env-Ver.

Helpers

  list
    Find repo checkouts in $PROJECTS.
  scm-list
    Find bare repos in $PROJECTS_SCM.
  scm-find <user>/<repo>
    Looks for (partial) [<user>/]<repo>.git (glob pattern) in SCM basedirs.
  scm-get VENDOR <user>/<repo>
    Create bare repo from vendor.
  src-get VENDOR <user>/<repo>
    Create checkout from local SCM. Fix remote to vendor, and $PROJECT_DIR
    symlink.

FIXME: cleanup below

    git-remote
    git-init-local
    git-init-remote
    git-drop-remote
    git-init-version
    git-missing
    git-init-src
    git-list
    git-files
    git-grep
    git-features
    gitrepo
    git-import

See also:

    htd vcflow
    vc
'


htd__gitremote()
{
  local remote_dir= remote_hostinfo= remote_name=
  lib_load gitremote

  test -n "$*" || set -- "$HTD_GIT_REMOTE"

  # Insert empty arg if first represents UCONF:git:remotes sh-props file
  test -e $UCONF/etc/git/remotes/$1.sh -a $# -le 2 && {
    # Default command to 'list' when remote-id exists and no further args given
    test $# -eq 1 && set -- "list" "$@" || set -- url "$@"
  }

  test -n "$1" || set -- list
  subcmd_prefs=gitremote_ try_subcmd_prefixes "$@"
}



htd__git_init_local() # [ Repo ]
{
  local remote=local
  repo="$(basename "$PWD")"
  [ -n "$repo" ] || error "Missing project ID" 1

  BARE=/srv/scm-git-local/$NS_NAME/$repo.git
  [ -d $BARE ] || {
      log "Creating temp. bare clone"
      git clone --bare . $BARE
    }

  remote_url="$(git config remote.$remote.url)"
  test -n "$remote_url" && {
    test "$remote_url" = $BARE || error "$remote not $BARE just created" 1
  } || {
    git remote add $remote $BARE
  }
}

htd__git_init_remote() # [ Repo ]
{
  [ -e .git ] || error "No .git directory, stopping remote init" 0
  test -n "$HTD_GIT_REMOTE" || error "No HTD_GIT_REMOTE" 1
  local repo= remote=$HTD_GIT_REMOTE BARE=

  # Create local repo if needed
  htd__git_init_local || warn "Error initializing local repo ($?)"

  # Remote repo, idem.
  local $(htd__gitremote sh-env "$remote" "$repo")
  {
    test -n "$remote_hostinfo" && test -n "$remote_repo_dir"
  } ||
    error "Incomplete env" 1

  ssh_cmd="mkdir -v $remote_repo_dir"
  ssh $remote_hostinfo "$ssh_cmd" && {

    log "Syning new bare repo to $remote_scp_url"
    rsync -azu $BARE/ $remote_scp_url

  } ||
    warn "Remote exists, checking remote '$remote'"

  # Initialise remotes for checkout
  {
    echo $remote $remote_scp_url
    echo local $BARE
    echo $hostname $hostname.zt:$BARE
  } | while read rt rurl
  do
    url="$(git config --get remote.${rt}.url)"
    test -n "$url" && {
      test "$rurl" = "$url" || {
        warn "Local remote '$rt' does not match '$rurl'"
      }
    } || {
      git remote add $rt $rurl
      git fetch $rt
      log "Added remote $rt $rurl"
    }
  done
}

htd__git_drop_remote()
{
  [ -n "$1" ] && repo="$1" || repo="$PROJECT"
  log "Checking if repo exists.."
  ssh_opts=-q
  htd__gitremote | grep $repo || {
    error "No such remote repo $repo" 1
  }
  source_git_remote # FIXME
  log "Deleting remote repo $remote_user@$remote_host:$remote_dir/$repo"
  ssh_cmd="rm -rf $remote_dir/$repo.git"
  ssh -q $remote_user@$remote_host "$ssh_cmd"
  log "OK, $repo no longer exists"
}

htd__git_init_version()
{
  local readme="$(echo [Rr][Ee][Aa][Dd][Mm][Ee]"."*)"

  test -n "$readme" && {
    fnmatch "* *" "$readme" && { # Multiple files
      warn "Multiple Read-Me's ($readme)"
    } ||
      note "Found Read-Me ($readme)"

  } || {
    readme=README.md
    {
      echo "Version: 0.0.1-dev"
    } >$readme
    note "Created Read-Me ($readme)"
  }

  grep -i '\<version\>[\ :=]*[0-9][0-9a-zA-Z_\+\-\.]*' $readme >/dev/null && {

    test -e .versioned-files.list ||
      echo "$readme" >.versioned-files.list
  } || {

    warn "no verdoc, TODO: consult scm"
  }

  # TODO: gitflow etc.
  git describe ||
    error "No GIT description, tags expected" 1
}


# List everything in  HTD_GIT_REMOTE repo collection

# Warn about missing src or project
htd__git_missing()
{
  test -d /srv/project-local || error "missing local project folder" 1
  test -d /srv/scm-git-local || error "missing local git folder" 1

  htd__gitremote | while -r read repo
  do
    test -e /srv/scm-git-local/$repo.git || warn "No src $repo" & continue
    test -e /srv/project-local/$repo || warn "No checkout $repo"
  done
}

# Create local bare in /src/
htd__git_init_src()
{
  test -d /srv/scm-git-local || error "missing local git folder" 1

  htd__gitremote | while read repo
  do
    fnmatch "*annex*" "$repo" && continue
    test -e /srv/scm-git-local/$repo.git || {
      git clone --bare $(htd git-remote $repo) /srv/scm-git-local/$repo.git
    }
  done
}


htd_man_1__git_list='List files at remove, or every src repo for current Ns-Name
'
htd__git_list()
{
  test -n "$1" || set -- $(echo /src/*/$NS_NAME/*.git)
  for repo in $@
  do
    echo $repo
    git ls-remote $repo
  done
}

htd_man_1__git_files='List or look for files'
htd_spc__git_files='git-files [ REPO... -- ] GLOB...'
htd_flags__git_files=ia
htd__git_files()
{
  local pat="$(compile_glob $(lines_to_words $arguments.glob))"
  read_nix_style_file $arguments.repo | while read repo
  do
    cd "$repo" || continue
    note "repo: $repo"
    # NOTE: only lists files at HEAD branch
    git ls-tree --full-tree -r HEAD |
        awk '{print $NF}' |
        sed 's#^#'"$repo"':HEAD/#' | grep "$pat"
  done
}
htd_argsv__git_files=arg-groups-r
htd_arg_groups__git_files="repo glob"
#htd_defargs_repo__git_files=/src/*/*/*/
htd_defargs_repo__git_files=/srv/scm-git-local/$NS_NAME/*.git


htd_man_1__git_grep='Run git-grep for every repository.

To run git-grep with bare repositories, a tree reference is required.

With `-C` interprets argument as shell command first, and passes ouput as
argument(s) to `git grep`. Defaults to `git rev-list --all` output (which is no
pre-run but per exec. repo).

If env `repos` is provided it is used iso. stdin.
Or if `dir` is provided, each "*.git" path beneath that is used. Else uses the
arguments.

If stdin is attach to the terminal, `dir=/src` is set. Without any
arguments it defaults to scanning all repos for "git.grep".

TODO: search checkouts as well, not only git bare repos
TODO: spec
'
htd_spc__git_grep='git-grep [ -C=REPO-CMD ] [ RX | --grep= ] [ GREP-ARGS | --grep-args= ] [ --dir=DIR | REPOS... ] '
htd_flags__git_grep=liAO
htd__git_grep()
{
  eval set -- $(lines_to_args "$arguments") # Remove options from args
  test -n "$grep" || { test -n "$1" && { grep="$1"; shift; } || grep='\<git.grep\>'; }

  test -n "$grep_args" -o -n "$grep_eval" && {
    note "Using env args:'$grep_args' eval:'$grep_eval'"
  } || {

    trueish "$C" && {
      test -n "$1" && {
        grep_eval="$1"; shift
      }
    }

    test -n "$1" && { grep_args="$1"; shift; } || { #grep_args=master
        trueish "$all_revs" && {
          grep_eval='$(git br|tr -d "*\n")'
        } ||
          grep_eval='$(git rev-list --all)';
      }
  }

  note "Running ($(var2tags grep C grep_eval grep_args))"
  gitrepos "$@" | { while read repo
    do
      {
        stderr info "$repo:"
        cd $repo || continue
        test -n "$grep_eval" && {
          eval git --no-pager grep -il "'$grep'" "$grep_eval" || { r=$?
            test $r -eq 1 && continue
            warn "Failure in $repo ($r)"
          }
        } || {
          git --no-pager grep -il "$grep" $grep_args || { r=$?
            test $r -eq 1 && continue
            warn "Failure in $repo ($r)"
          }
        }
      } | sed 's#^.*#'$repo'\:&#'
    done
  }
  #| less
  note "Done ($(var2tags grep C grep_eval grep_args repos))"
}
htd_libs__git_grep=sys-htd


htd_man_1__gitrepo='List local GIT repositories

Arguments are passed to htd-expand, repo paths can be given verbatim.
This does not check that paths are GIT repositories.
Defaults effectively are:

    --dir=/srv/scm-git-local/$NS_NAME *.git``
    --dir=/srv/scm-git-local/$NS_NAME -

Depending on wether there is a terminal or pip/file at stdin (fd 0).
'
htd_spc__gitrepo='gitrepo [--(,no-)expand-dir] [--repos=] [--dir=] [ GLOBS... | PATHS.. | - ]'
htd_env__gitrepo="dir="
htd_flags__gitrepo=eiAO
htd__gitrepo()
{
  eval set -- $(lines_to_args "$arguments") # Remove options from args
  stderr info "Running '$*' ($(var2tags grep repos dir stdio_0_type))"
  gitrepos "$@"
}


htd__git_import()
{
  test -d "$1" || error "Source dir expected" 1
  note "GIT import from '$1'..."
  find $1 | cut -c$(( 2 + ${#1}))- | while read pathname
  do
    test -n "$pathname" || continue
    test -d "$1/$pathname" && mkdir -vp "$pathname"
    test -L "$pathname" && continue
    test -f "$pathname" || continue
    trueish "$dry_run" && {
      echo mv -v "$1/$pathname" "$pathname"
    } || {
      mv -v "$1/$pathname" "$pathname"
    }
  done
}

htd_libs__git=git\ htd-git\ git-htd
htd_flags__git=l
htd__git()
{
  test -n "$1" || set -- info
  subcmd_prefs=${base}_git_\ git_ try_subcmd_prefixes "$@"
}


htd_libs__github=github
htd_man_1__github='Github lib.

    info
    find
'

htd_flags__github=fl
htd__github()
{
  test -n "$1" || set -- help
  subcmd_prefs=${base}_github__\ ${base}_github_\ github_ try_subcmd_prefixes "$@"
}

htd_github__help ()
{
  echo "$htd_man_1__github"
}

htd_man_1__find="Find file by name, or abort.

See also 'git-grep' and 'content' to search based on content.
"
htd_spc__find="-f|find <id>"
htd__find()
{
  test -n "$1" || error "name pattern expected" 1
  test -z "$2" || error "surplus argumets '$2'" 1

  note "Compiling ignores..."
  local find_ignores="$(find_ignores $IGNORE_GLOBFILE)"

  test -n "$FINDPATH" || {
    note "Looking in all volumes"
    FINDPATH=$(echo /srv/volume-[0-9]*-[0-9]* | tr ' ' ':')
  }

  lookup_path_list FINDPATH | while read v
  do
    vr="$(cd "$v"; pwd -P)"
    note "Looking in $v ($vr)..."

    # NOTE: supress output of any permision, non-existent or other IO error
    eval find "$vr" -iname "$1" 2>/dev/null

    #echo find $v $find_ignores -o -iname "$1" -a -print
    #eval find $v "$find_ignores -o \( -type l -o -type f \) -a -print "
    #echo "\l"
  done

  note "Looking in repositories"
  htd git-files "$1"
}
htd_libs__find=sys\ ignores\ code


#
