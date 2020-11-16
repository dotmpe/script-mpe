#!/usr/bin/env make.sh
#
# SCM util functions and pretty prompt printer for Bash, GIT
# TODO: other SCMs, BZR, HG, SVN (but never need them so..)
#
#HELP="vc - version-control helper functions "
set -eu

version=0.0.4-dev # script-mpe


# Script subcmd's funcs and vars

C_cached()
{
  test -n "$C" || return 1
  C_mtime=$(statusdir.sh get $C_key:time || return $?)
  test -n "$C_mtime" || return 2
  test $C_mtime -ge $c_mtime || return 3
}


vc_main_usage()
{
  echo 'Usage: '
  echo "  $scriptname <cmd> [<args>..]"
}

vc__commands()
{
  echo 'Commands'
  echo '  status             TODO'
  echo '  ls-trees           Find all SCM checkouts below the current dir '
  echo '                     (roots only, set recurse to list nested checkous).'
  echo '  ls-nontree         Find any path not included in a checkout. '
  echo '  list-submodules    '
  echo '  list-prefixes      '
  echo '  list-subrepos      XXX: List all repositories below, excluding submodules. '
  echo ''
  echo 'Utils'
  echo '  print-all <path>   Dump some debug info on given (versioned) paths'
  echo '  ps1                Print PS1'
  echo '  screen             '
  echo '  mtime              '
  echo '  flush              '
  echo '  print-all          '
  echo '  prompt-command     '
  echo '  gh                 Clone from github'
  echo '  largest-objects (10)'
  echo '                     List the SHA1 sums of the largest GIT objects.'
  echo '  path-for-object <sha1>'
  echo '                     Given SHA1 object, its current path.'
  echo '  contains REPO FILE'
  echo '                     Find matching FILE content in REPO. '
  echo '  list-objects       Verify all packages. '
  echo '  object-contents    '
  echo '  projects           XXX: list remotes in projectdir'
  echo '  remotes            List remotes in repo. '
  echo '  local              Find or create bare remote (default: $SCM_GIT_DIR)'
  echo ''
  echo '  regenerate         Regenerate local excludes. '
  echo '  regenerate-stale   Regenerate when local ignores are newer than excludes. '
  echo ''
  echo 'File Patterns'
  echo '  excludes           Patterns to paths kept out of version control '
  echo '                     (unversioned-files [uf]). '
  echo '  temp-patterns      Patterns to excluded files that will or need to be '
  echo '                     regenerated if removed . '
  echo '  cleanables         Patterns to excluded files that can be cleaned '
  echo '                     but are required while the checkout exists. '
  echo '  excludes-regex     '
  echo '  cleanables-regex   '
  echo '  temp-patterns-regex '
  echo '                     Compile/echo globlists to regexes. '
  echo ''
  echo 'Files'
  echo '  uf|unversioned-files '
  echo '                     List untracked paths excluding ignored paths. '
  echo '  ufx|excluded|untracked-files '
  echo '                     List every untracked path (including ignore). '
  echo '  uft|temporary-files '
  echo '                     List (untracked) temporary file paths'
  echo '  ufc|cleanable-files '
  echo '                     List (untracked) cleanable file paths'
  echo '  ufu|uncleanable-files '
  echo '                     List untracked paths excluding temp or cleanable. '
  echo ''
  echo 'Annex'
  echo '  annex-unused       Show keys of stored objects without path using them. '
  echo '  annex-show-unused  Show commit logs for unused keys. '
  echo '  annex-clear-unused [<to>]'
  echo '                     Drop the unused keys, or move to remote. '
  echo '  annex-contains     '
  echo '  annex-local        Find or create remote annex repo in $ANNEX_DIR'
  echo ''
  echo 'Other commands: '
  echo '  -e|edit            Edit this script.'
  echo '  help               Give a combined usage, command and docs. '
  echo '  docs               Echo manual page. '
  echo '  commands           Echo this comand description listing.'
}

vc__help()
{
  echo "$base/$version - Reports on SCM state, build short description. "
  echo
  test -z "${1-}" && {
    vc_main_usage
    echo
    echo "Default command: "
    echo "  $scriptname (print-all) [PATH...]"
    echo
    echo "For example to be embedded in PS1: "
    echo "  $scriptname ps1"
    echo
    echo "Tokens:"
    echo "      *     modified"
    echo "      +     stage"
    echo "      $     stash"
    echo "      ~     untracked"
    echo "      #     no HEAD"
    echo "   DIR!:    inside checkout metafolder"
    echo "   BARE:    inside bare repository"
    echo ''
    vc__docs
  } || {

    echo_help $1 || {
      for func_id in "$1" "${base}__$1" "$base-$1"
      do
          htd_function_comment $func_id 2>/dev/null || continue
          htd_function_help $func_id 2>/dev/null && return 1
      done
      error "Got nothing on '$1'" 1
    }
  }
}

vc__docs()
{
  echo "See vc commands for full comand list"
  echo "See htd and dckr for other scripts"
}


vc__edit()
{
  [ -n "$1" ] && fn=$1 || fn=$(which $scriptname)
  [ -n "$fn" ] || fn=$(which $scriptname.sh)
  [ -n "$fn" ] || error "Nothing to edit" 1
  ( __load_lib= $EDITOR $fn )
}
vc_als___e=edit



# Vars legenda:
#
# vc_flags_git : cbwisur
# c: ''|'BARE:'
# b: branchname
# w: '*'
# i: '+'|'#'
# s: '$'
# u: '~'
#

# checkout dir
# for regular checkouts, the parent dir
# for modules, one level + prefix levels higher
__vc_git_codir()
{
  git="$(vc_gitdir "$1")"

  fnmatch "*/.git" "$git" \
    || while true
      do
        git="$(dirname "$git")"
        fnmatch "*/.git" "$git" && break
      done

  dirname "$git"
}


vc__type()
{
  vc_getscm || return $?
  echo $scm
}

# Switch the version control system detected for the current directory.
# (First GIT, then BZR). Then make a pretty info string representing the status
# of the working tree and repository.
#
# <userpath>[<branchname><branchstate>]<branchpath>
# Version Control part for prompt, state indicators:
# + : added files
# * : modified "
# - : removed "
# ? : untracked "
__vc_status()
{
  test -n "${1-}" || set -- "$PWD"
  test -d "${1-}" || error "No such directory '$1'" 3

  local w short repo sub realcwd

  realcwd="$(cd "$1"; pwd -P)"
  short="$(realpath "$1")"
  test -n "$short" || err "homepath" 1

  local git="$(vc_gitdir "$realcwd")"
  local bzr="$(vc_bzrdir "$realcwd")"

  if [ -n "$git" ]; then

    vc_check_git "$git" || {
      echo "$realcwd (git:unborn)"
      return
    }

    checkoutdir="$(cd "$realcwd"; git rev-parse --show-toplevel)"

    [ -n "$checkoutdir" ] && {

      rev="$(cd "$realcwd"; git show "$checkoutdir" | grep '^commit' \
        | sed 's/^commit //' | sed 's/^\([a-f0-9]\{9\}\).*$/\1.../')"
      sub="${realcwd##$checkoutdir}"
    } || {

      realgitdir="$(cd "$git"; pwd -P)"
      rev="$(vc_revision_git)"
      #rev="$(cd $realcwd; git show . | grep '^commit'|sed 's/^commit //' | sed 's/^\([a-f0-9]\{9\}\).*$/\1.../')"
      realgit="$(basename "$realgitdir")"
      sub="${realcwd##$realgit}"
    }

    short="${short%$sub}"
    echo "$short" $(vc_flags_git "$realcwd" "[git:%s%s%s%s%s%s%s%s $rev]")"$sub"

  else if [ -n "$bzr" ]; then
    #if [ "$bzr" = "." ];then bzr="./"; fi
    realbzr="$(cd "$bzr"; pwd -P)"
    realbzr="${realbzr%/.bzr}"
    sub="${realcwd##$realbzr}"
    short="${short%$sub/}"
    local revno=$(bzr revno)
    local s=''
    if [ "$(bzr status|grep added)" ]; then s="${s}+"; fi
    if [ "$(bzr status|grep modified)" ]; then s="${s}*"; fi
    if [ "$(bzr status|grep removed)" ]; then s="${s}-"; fi
    if [ "$(bzr status|grep unknown)" ]; then s="${s}~"; fi
    [ -n "$s" ] && s="$s "
    echo "$short$PSEP [bzr:$s$revno]$sub"

  #else if [ -d ".svn" ]; then
  #  local r=$(svn info | sed -n -e '/^Revision: \([0-9]*\).*$/s//\1/p' )
  #  local s=""
  #  local sub=
  #  if [ "$(svn status | grep -q -v '^?')" ]; then s="${s}*"; fi
  #  if [ -n "$s" ]; then s=" ${s}"; fi;
  #  echo "$short$PSEP [svn:r$r$s]$sub"
  else
    echo "$short"
  fi;fi;
}

__vc_screen ()
{
  test -n "$1" || set -- "$(pwd -P)"
  local w=$1 short repo sub

  short=$(short "$1")

  local gitdir=$(vc_gitdir "$1")
  test -z "$gitdir" || {

    vc_check_git "$gitdir" || {
      echo "$w (git:unborn)"
      return
    }
    checkoutdir="$(git rev-parse --show-toplevel)"
    test -z "$checkoutdir" || {
      rev="$(vc_revision_git)"
      sub="${w##$checkoutdir}"
      echo $(basename "$w") $(vc_flags_git "$git" "[git:%s%s%s%s%s%s%s%s $rev]")
    return
    }
  }

  echo "$short"
}


__vc_pull ()
{
  cd "$1"
  local git=$(vc_gitdir)
  local bzr=$(vc_bzrdir)
  if [ "$git" ]; then
    git pull;
  else if [ "$bzr" ]; then
    bzr pull;
  else if [ -d ".svn" ]; then
    svn update
  fi; fi; fi;
}

__vc_push ()
{
  cd "$1"
  local git=$(vc_gitdir)
  local bzr=$(vc_bzrdir)
  if [ "$git" ]; then
    git push origin master;
  else if [ "$bzr" ]; then
    bzr push;
#  else if [ -d ".svn" ]; then
#      svn
  fi; fi;
}


# get a/the vendor/project ID's
# many possible ways to get it, defaults to something github-ish.
# But let .package.sh decide method
# must be called from within checkout base dir
__vc_gitrepo()
{
  test -e .git || err "not a checkout" 240

  test -z "$package_mpe_meta_get_repo" \
    || set -- "$package_mpe_meta_get_repo"

  test -n "$1" || {
    test -z "$package_repo" || set -- "package-repo"
  }

  test -n "$1" || {
    test -z "$package_vendor" -a -z "$package_id" \
      || set -- package-vnd-id
  }

  test -n "$1" || {
      set -- "$(
    git remote | while read remote
    do
      fnmatch "git@github.com:*" "$(git config remote.$remote.url)" \
        && {
          echo remote-$remote
          break
        }
      done )"
  }

  test -n "$1" || {

      set -- "$(
    git remote | while read remote
    do
      fnmatch "$HTD_GIT_REMOTE_URL*" "$(git config remote.$remote.url)" \
        && {
          echo remote-HTD-$remote
          break
        }
      done )"
  }

  case "$1" in
    package-repo )
        echo $package_repo
      ;;
    package-vnd-id )
        echo $package_vendor/$package_id
      ;;
    remote-*-* )
        local \
          remote_key=$(echo $1 | cut -c8- | cut -d- -f 1) \
          remote_local=$(echo $1 | cut -c8- | cut -d- -f 2)
        local \
          remote_name=$(eval echo \$${remote_key}_GIT_REMOTE) \
          remote_url_base=$(eval echo \$${remote_key}_GIT_REMOTE_URL) \
          remote_url=$(git config remote.$remote_local.url)
        local \
          e=$(( ${#remote_url} - 4 )) l=$(( 2 + ${#remote_url_base} ))

        local repo=$(echo $remote_url | cut -c$l-$e)

        echo $remote_name/$repo
      ;;
    remote-* )
        local remote=$(echo $1 | cut -c8-)
        git config remote.$remote.url | sed -E '
          s/^.*:([A-Za-z0-9_-]+)\/([A-Za-z0-9_-]+)(\.git)?$/\1\/\2/'
      ;;
    * )
        error "Illegal vc gitrepo method '$1'" 1
      ;;
  esac
}


# List checkouts below dir. Normally stops at any SCM root, unless recurse=true
vc__ls_trees()
{
  test -n "$1" || set -- .
  trueish "$recurse" && {
    # NOTE: This recurse causes SVN to yield just about every dir below it
    find $1 \
      -type d -a \( \
        -iname '*.svn*' -prune -o \
        -iname '*.bzr*' -prune -o \
        -iname '*.git*' -prune -o \
        -iname '*.hg*'  -prune \
      \) -o -type d -a \( \
        -exec test -d "{}/.bzr" \; -o \
        -exec test -d "{}/.git" \; -o \
        -exec test -d "{}/.hg" \; -o \
        -exec test -d "{}/.svn" \; \
      \) -a -print
  } || {
    find $1 \
      -type d -a \( \
        -iname '*.svn*' -prune -o \
        -iname '*.bzr*' -prune -o \
        -iname '*.git*' -prune -o \
        -iname '*.hg*'  -prune \
      \) -o -type d -a \( \
        -exec test -d "{}/.bzr" \; -prune -o \
        -exec test -d "{}/.git" \; -prune -o \
        -exec test -d "{}/.hg" \;  -prune  -o \
        -exec test -d "{}/.svn" \; -prune \
      \) -a -print
  }
}

# List paths not included in a checkout. Usefull to find and deal wti hstray files
vc__ls_nontree()
{
  find $d \
    -type d -a \( \
      -iname '*.svn*' -prune -o \
      -iname '*.bzr*' -prune -o \
      -iname '*.git*' -prune -o \
      -iname '*.hg*'  -prune -o \
      -exec test -d "{}/.bzr" \; -prune -o \
      -exec test -d "{}/.git" \; -prune -o \
      -exec test -d "{}/.hg" \;  -prune  -o \
      -exec test -d "{}/.svn" \; -prune \
    \) -a -prune -o -print
}


### Command Line handlers

vc_flags__stat=f
vc__stat()
{
  test -n "${1-}" || set -- . "${2-}"
  test -n "${2-}" || set -- "$1" "%s%s%s%s%s%s%s%s"
  local scm= scmdir=
  vc_getscm "$1"
  vc_flags_${scm} "$@" || return $?
}
# TODO: alias
#vc_als__status=stat
vc__st()
{
  vc__stat "$@"
}
vc__status()
{
  vc__stat "$@"
}


vc__bits()
{
  __vc_status
}

vc__flags()
{
  test -n "${1-}" || set -- "$PWD"
  scmdir="$(basename "$(vc_scmdir "$1")")"
  case "$scmdir" in
    .git )
        echo "$scmdir$(vc_flags_git "$1" || return $?)"
      ;;
    .bzr )
        echo "$scmdir$(vc_flags_bzr "$1" || return $?)"
      ;;
    .svn )
        echo "$scmdir$(vc_flags_svn "$1" || return $?)"
      ;;
    .hg )
        echo "$scmdir$(vc_flags_hg "$1" || return $?)"
      ;;
    * )
        error "$scmdir" 1
      ;;
  esac
}


vc_man_1__ps1="Print VC status in the middle of PWD. ".
vc_flags__ps1=x
vc_spc__ps1="ps1"
vc__ps1()
{
  c="$(__vc_status "$PWD" || return $?)"
  echo "$c"
}
vc_C_exptime__ps1=0
vc_C_validate__ps1="vc__mtime \$gtd"


vc_man_1__screen="Print VC status in the middle of PWD. ".
vc_flags__screen=x
vc_spc__screen="screen"
vc__screen()
{
  test -n "$gtd" || { pwd; return; }
  c="$(__vc_screen "$(dirname "$gtd")" || return $?)"
  echo "$c"
}
vc_C_exptime__screen=0
vc_C_validate__screen="filemtime \$cwd"


vc_man_1__mtime="Return last modification time for GIT head or stage"
vc__mtime()
{
  test -n "$1" || set -- "$gtd"

  # Return highest mtime
  (
    filemtime "$1"/index
    filemtime "$1"/HEAD
  ) \
    | awk '$0>x{x=$0};END{print x}'
}


vc_man_1__flush="Delete all subcmd value caches"
vc__flush()
{
  for subcmd_ in ps1 stat
  do
    stat_key C
    subcmd=$subcmd_ membash delete $C_key 2>&1 >/dev/null || continue
  done
}

# Print --vc-sttus for every given PATH
vc__print_all () # PATHS...
{
  test $# -gt 0 || return 98
  local path scm
  for path in "$@"
  do
    vc_getscm "$path" || {
      warn "No SCM checkout at <$path>"
      continue
    }
    echo vc-status[$path]=\"$(__vc_status "$path")\"
  done
}


# special updater (for Bash PROMPT_COMMAND)
vc__prompt_command()
{
  test -n "${1-}" || set -- "$PWD"
  test -d "${1-}" || error "No such directory '$1'" 3

  # cache response in file
  pwdref="$(echo "$1" | tr '/' '-' )"
  cache="$(statusdir.sh assert-dir vc prompt-command "$pwdref")"

  test ! -e "$cache" -o "$1"/.git -nt "$cache" && {
    __vc_status "$1" > "$cache"
  }

  cat "$cache"
}


vc__list_submodules()
{
  vc_git_submodules
}


vc_man_1__gh="Clone from Github to subdir, adding as submodule if already in checkout. "
vc_spc__gh="gh <repo> [<prefix>]"
vc__gh()
{
  test -n "$1" || error "Need repo name argument" 1
  str_match "$1" "[^/]*" && {
    repo=dotmpe/$1; prefix=$1; } || {
    repo=$1; prefix=$(basename "$1"); }
  shift 1
  test -n "$1" && prefix=$1/$prefix
  giturl=git@github.com:$repo.git
  test -n "$debug" && {
    echo giturl=$giturl
    echo repo=$repo
    echo prefix=$prefix
  }
  git=git
  test -n "$dry" && {
    log "*** DRY-RUN ***"
    git="echo git"
  }
  test -e .git && {
    test -d .git && {
      log "Adding submodule $giturl to $PWD/$prefix.."
      ${git} submodule add $giturl $prefix
      log "Added submodule $giturl to $PWD/$prefix"
    } || {
      # TODO: find/print root. then go there. see vc.sh
      error "Please recede to root and use prefix to add submodule" 1
    }
  } || {
    log "Cloning $giturl to $PWD/$prefix.."
    ${git} clone "$giturl" "$prefix"
    log "Cloned $giturl to $PWD/$prefix"
  }
}

vc__largest_objects()
{
  test -n "$1" || set -- 10
  test -n "$scriptpath" || error scriptpath 11
  $scriptpath/git-largest-objects.sh "$1"
}

# list commits for object sha1
vc__commit_for_object()
{
  test -n "$1" || error "provide object hash" 1
  while test $# -gt 0
  do
    git rev-list --all |
    while read commit; do
      if git ls-tree -r $commit | grep -q $1; then
        echo $commit
      fi
    done
    shift 1
  done
}

vc__count_packs()
{
  echo .git/objects/pack/pack-*.idx | wc -l
}

# print tree, blob, commit, etc. objs
vc__list_objects()
{
  test -n "$1" || set -- "-v"
  git verify-pack "$@" .git/objects/pack/pack-*.idx
  pack_cnt=$(vc__count_packs)
  test $pack_cnt -gt 0 && {
    test $pack_cnt -eq 1 && {
      note "One package verified"
    } || {
      note "Multple ($pack_cnt)) packages verified"
    }
  } || {
    error "No packages"
  }
}

# Pretty print GIT object
vc__object_contents()
{
  git cat-file -p $1
}


## List Exclude Patterns

vc_man_1__excludes='List path ignore patterns

TODO: see ignores
'
vc__excludes()
{
  # (global) core.excludesfile setting
  global_excludes=$(echo $(git config --get core.excludesfile))
  test ! -e "$global_excludes" || {
    note "Global excludes:"
    cat $global_excludes
  }

  note "Local excludes (repository):"

  test -e .git/info/exclude && {
    cat .git/info/exclude | grep -v '^\s*\(#\|$\)'
  }

  test -s ".gitignore" && {
    note "Local excludes"
    cat .gitignore
  } || {
    note "No local excludes"
  }
}

vc__excludes_regex()
{
  vc__regenerate_stale || return $?
  globlist_to_regex .git/info/exclude || return $?
}

vc__temp_patterns() { eval read_nix_style_file $vc_temp_gl || return $?; }
vc__temp_patterns_regex() { globlist_to_regex $vc_temp_gl || return $?; }
vc__cleanables() { eval read_nix_style_file $vc_clean_gl || return $?; }
vc__cleanables_regex() { globlist_to_regex $vc_clean_gl || return $?; }


vc_als__tracked=tracked-files
vc__tracked_files()
{
  local scm= scmdir=
  vc_getscm || return $?
  vc_tracked "$@"
}


# List unversioned files (including temp, cleanable and any excluded)
vc_als__untracked=untracked-files
vc_als__ufx=untracked-files
vc_als__excludes=untracked-files
vc__untracked_files()
{
  local scm= scmdir=
  vc_getscm || return $?
  vc_untracked "$@"
}

# List untracked paths. Unversioned files excluding ignored/excluded
vc_als__unversioned=unversioned-files
vc_als__uf=unversioned-files
vc__unversioned_files()
{
  test -z "$*" || error "unexpected arguments" 1

  local scm= scmdir=
  vc_getscm || return $?
  vc_unversioned "$@"
}

# List (untracked) cleanable files
vc_als__ufc=unversioned-cleanable-files
vc__unversioned_cleanable_files()
{
  note "Listing unversioned cleanable paths"
  vc__cleanables_regex > .git/info/exclude-clean.regex || return $?
  vc__untracked_files | grep -f .git/info/exclude-clean.regex || {
    warn "No cleanable files"
    return 1
  }
}

vc__uft() { vc__unversioned_temporary_files ; }
vc__unversioned_temporary_files()
{
  note "Listing unversioned temporary paths"
  vc__temp_patterns_regex > .git/info/exclude-temp.regex || return $?
  vc__untracked_files | grep -f .git/info/exclude-temp.regex || {
    warn "No temporary files"
    return 1
  }
}

vc__ufu() { vc__unversioned_uncleanable_files ; }
vc__unversioned_uncleanable_files()
{
  note "Listing unversioned, uncleanable paths"
  {
    vc__cleanables_regex
    vc__temp_patterns_regex
  } > .git/info/exclude-clean-or-temp.regex

  vc__untracked_files | grep -v -f .git/info/exclude-clean-or-temp.regex || {
    warn "No uncleanable files"
    return 1
  }
}
#vc_flags__ufu=f
#vc_flags__unversioned_uncleanable_files=f

vc__modified() { vc__modified_files ; }
vc__modified_files()
{
  test -z "$*" || error "unexpected arguments" 1

  local scm= scmdir=
  vc_getscm || return $?
  vc_modified
}

vc__staged() { vc__staged_files ; }
vc__staged_files()
{
  test -z "$*" || error "unexpected arguments" 1

  local scm= scmdir=
  vc_getscm || return $?
  vc_staged
}



# Annex diag.
vc__annex_unused()
{
  git annex unused | grep '\s\s*[0-8]\+\ \ *.*$' | \
  while read line
  do
    echo $line
  done
}

vc__annex_show_unused()
{
  vc__annex_unused | while read num key
  do
    echo "GIT log for '$key'"
    git log --stat -S"$key"
  done
}

vc__annex_clear_unused()
{
  test -z "$1" && {
    local cnt
    cnt="$(vc_annex_unused | tail -n 1 | cut -f 1 -d ' ')"
    vc__annex_unused | while read num key
    do
      echo $num $key
    done
    echo cnt=$cnt
    read -p 'Delete all? [yN] ' -n 1 user
    echo
    test "$user" = 'y' && {
      while test "$cnt" -gt 0
      do
        git annex dropunused --force $cnt
        cnt=$(( $cnt -1 ))
      done
    } || {
      error 'Cancelled' 1
    }
  } || {
    git annex move --unused --to "$1"
  }
}

vc_man_1__contains="Find matching FILE content in REPO. Based on git hash-object. "
vc_spc__contains="REPO FILE"
vc__contains()
{
  test -n "$1" || error "expected file path argument" 1
  test -f "$1" || error "not a file path argument '$1'" 1
  test -n "$2" || set -- "$1" "."
  test -d "$2/.git" || error "expected checkout dir" 1
  test -z "$3" || error "surplus args" 1

  sha1="$(git hash-object "$1")"
  std_info "SHA1: $sha1"

  { ( cd "$2" ; git rev-list --objects --all | grep "$sha1" ); } && {
    note "Found regular GIT object"
  } || vc__annex_contains "$1" "$2" || {
    warn "Unable to find path in GIT at @$2: '$1'"
  }
}

vc__annex_contains()
{
  test -n "$1" || error "expected file path argument" 1
  test -f "$1" || error "not a file path argument '$1'" 1
  test -n "$2" || set -- "$1" "."
  test -z "$3" || error ""

  size="$(stat -Lf '%z' "$1")"
  sha256="$(shasum -a 256 "$1" | cut -f 1 -d ' ')"
  keyglob='*s'$size'--'$sha256'.*'
  std_info "SHA256E key glob: $keyglob"
  { find $2 -ilname $keyglob | while read path; do echo $path;ls -la $path; done;
  } || warn "Found nothing for '$keyglob'"
}

# Search all repos/branches for file with content
vc__grep_file()
{
  test -n "$1" || error "Filename required" 1
  test -n "$2" || error "Pattern required" 1
  local filename=$1 pattern="$2"
  shift 2
  test -n "$3" || error "Checkout path(s) required" 1

  local cwd=$PWD
  for checkout in $3
  do
    (
      cd "$cwd/$checkout"
      for b in HEAD $(git ls-remote . refs/heads/* | cut -f 2)
      do
        git show $b:$filename | grep -q "$2" && echo "$checkout $b"
      done
    )
  done 2>/dev/null
}

# List submodule prefixes
vc__list_prefixes()
{
  git submodule foreach | sed "s/.*'\(.*\)'.*/\1/" # vim syntax fix: '"
}

# List all nested repositories, excluding submodules
# XXX this does not work properly, best use it from root of repo
# XXX: takes subdir, and should in case of being in a subdir act the same
vc__list_subrepos()
{
  local cwd=$PWD prefixes=$(setup_tmpf .prefixes)
  basedir="$(dirname "$(vc_gitdir "$1")")"
  test -n "$1" || set -- "."

  cd "$basedir"
  vc__list_prefixes > $repfixes
  cd "$cwd"

  find $1 -iname .git | while read path
  do
    # skip root
    #test -n "$(realpath "$1/.git")" != "$(realpath "$path")" || continue

    # skip proper submodules
    match_grep_pattern_test "$(dirname "$path")" || continue
    grep_pattern="$p_"
    grep -q "$grep_pattern" $prefixes && {
      continue
    } || {
      echo "$(dirname $path)"
    }
  done
  rm $prefixes
#    git submodule foreach 'for remote in "$(git remote)"; do echo $remote; git
#    config remote.$remote.url  ; done'
}


vc__projects()
{
  test -f projects.sh || touch projects.sh

  local cwd=$PWD pwd=$(pwd -P)

  for gitdir in */.git
  do
    dir="$(dirname "$gitdir")"
    cd "$dir"
    git remote | while read remote
    do
      url=$(git config remote.$remote.url)
      grep -q ${dir}_${remote} $pwd/projects.sh || {
        echo "${dir}_${remote}=$url" >> $pwd/projects.sh
      }
    done
    cd "$cwd"
  done
}

vc__remotes() # [FMT] [DIR] []
{
  # FIXME: vc-remote lib
  test -n "$1" || set -- "$PWD" "$2"
  #test -n "$2" || set -- all
  vc_getscm "$1" || return $?
  vc_remotes "$@"
}

vc__remote()
{
  #test -n "$1" || set -- all
  vc_getscm "$PWD" || return $?
  vc_remote "$PWD" "$@"
}

vc__branch()
{
  local pwd=$PWD
  test -z "$1" || cd "$1"
  vc_getscm "." || return $?
  vc_branch
  test -z "$1" || cd "$pwd"
}

vc_als__branches=list-local-branches
vc__list_local_branches()
{
  local pwd=$PWD
  test -z "$1" || cd "$1"
  vc_getscm "." || return $?
  vc_branches
  test -z "$1" || cd "$pwd"
}

vc__list_all_branches()
{
  local pwd=$PWD
  test -z "$1" || cd "$1"
  vc_getscm "." || return $?
  #vc_branches all | while read f ; do basename "$f"; done | sort -u
  test -z "$1" || cd "$pwd"
}

# List branches
vc__branch_refs()
{
  test -n "$1" || error "branch name required" 1
  local ret= failed=
  git show-ref --verify -q "refs/heads/$1" && { echo "refs/heads/$1" ; ret=0 ; } || { ret=1; }
  test -n "$2" && {
    test "$2" != "*" || set -- "$(git remote)"
  } || set -- "$@" origin
  local branch="$1";
  shift
  while test $# -gt 0
  do
    git show-ref --verify -q "refs/remotes/$1/$branch" && {
      echo "refs/remotes/$1/$branch"
    } || {
      test "$r" = "0" -o "$r" = "2" || r=2
    }
    shift
  done
  return $r
}

# List branches, both local and remote by default
vc__branches()
{
  test -n "$1" || set -- all
  vc_getscm "$PWD" || return $?
  vc_branches "$@"
}

# Check wether the literal ref exists, ie:
# - named branches: refs/heads/*
# - remote branches: refs/remote/<remote>/*
vc__ref_exists()
{
  vc_ref_exists "$@"
}

# Check repository knows Branch, tag or commit
vc__exists() # Version [Remote]
{
  vc_exists "$@"
}

# Check wether branch name exists somewhere
vc__branch_exists() # Local or remote-prefixed ref (branch)
{
  vc_ref_exists "refs/heads/$1" && return
  vc_ref_exists "refs/remotes/$1" && return
  return 1
}

vc__local_branch_exists()
{
  test -z "$2" || error "Unexpected remote" 1
  vc_exists_local "$@"
}


# regenerate .git/info/exclude
# NOTE: a duplication is happening, but not no recursion, only once. As
# accumulated patterns (current contents) is unique-listed first, and then all
# items are added again grouped at each source path
vc__regenerate()
{
  local gitdir excludes
  gitdir="$(vc_gitrepo ${1-})" || return
  excludes=$gitdir/info/exclude

  test -e $excludes.header -o ! -e $excludes || backup_header_comment $excludes

  std_info "Resetting local GIT excludes file"
  read_nix_style_file $excludes | sort -u > $excludes.list
  cat $excludes.header $excludes.list > $excludes
  rm $excludes.list

  std_info "Adding other git-ignore files"
  for x in .gitignore-* $HOME/.gitignore*-global
  do
    test "$(basename "$x" .regex)" = "$(basename "$x")" || continue
    test -e $x || continue
    echo "# Source: $x" >> $excludes
    read_nix_style_file $x >> $excludes
  done

  note "Local excludes successfully regenerated <$excludes>"
}
vc__regen() { vc__regenerate "$@" ; }


vc_man_1__regenerate_stale='Regenerate GIT exclude file from user config
'
vc__regenerate_stale()
{
  for gexcl in .gitignore{-{clean,temp},}
  do
    test .git/info/exclude -nt $gexcl || {
      vc__regenerate
      return
    }
  done
}


vc_flags__gitrepo=fq
vc__gitrepo()
{
  __vc_gitrepo || return $?
}


# Add/update local git bare repo
vc_flags__local=fq
vc__local()
{
  test -n "$1" || set -- "SCM_GIT_DIR" "$2"
  test -n "$2" || set -- "$1" "git-local"
  test -z "$3" || error "surplus arguments '$3'" 1

  set -- "$@" "$(eval echo \$$1)"
  test -n "$3" || error "$1 empty" 1
  test -d "$3" || error "$1 is not a dir '$3'" 1

  git=$(__vc_git_codir)
  test -n "$git" || error "not a checkout" 230

  repo=$(__vc_gitrepo)
  test -n "$repo" || error "no repo found for CWD" 1

  test -e $3/$repo || {
    mkdir -p $(dirname $3/$repo)
    test -n "$clone_flags" || clone_flags=--bare
    git clone $clone_flags $git $3/$repo || {
      error "Failed creating bare clone '$2' '$3/$repo'" 1
    }
  }

  git config remote.$2.url >/dev/null && {
    test "$(git config remote.$2.url)" = "$3/$repo" \
      && note "Remote '$2' url up to date" \
      || {
        git remote set-url $2 $3/$repo \
          && note "Updated remote '$2' url" \
          || error "Failed updating remote '$2' url '$3/$repo'" 1
      }
  } || {
    git remote add $2 $3/$repo \
      && note "Added remote '$2'" \
      || error "Failed adding remote '$2' url '$3/$repo'" 1
    git annex fetch $2
  }
}

# Add/update for local annex-dir remote
# If in an annex checkout, get repo name, and add remote $ANNEX_DIR/<repo>.git
vc__annex_local()
{
  test -n "$1" || set -- "$ANNEX_DIR" "$2"
  test -n "$2" || set -- "$1" "annex-dir"

  clone_flags=" " \
  vc__local $1 $2 || return $?

  git annex sync $2 \
    && note "Succesfully synced annex with $2" \
    || error "Syncing annex with $2" 1
  echo "Press return to finish, or enter:"
  echo " 1|m[ove] or 2|c[opy] for annex contents to $2.."
  read act >/dev/null
  test -z "$act" || {
    case "$act" in
      1 | m* ) act=move;;
      2 | c* ) act=copy;;
    esac
    git annex $act --to $2 \
      || return $? \
      && note "Succesfully ran annex $act to $2"
  }
}


# Check wether the literal ref exists (named branches with refs/heads/, or remotes with
# refs/remote/<remote>/ prefix)
vc__git_ref_exists()
{
  git show-ref --verify -q "$1" || return $?
}

# Check for local or remote branch name
vc__git_branch_exists()
{
  vc__git_ref_exists "refs/heads/$upstream" && return
  vc__git_ref_exists "refs/remotes/$upstream" && return
  return 1
}


vc__roots()
{
  vc_roots
}


vc__epoch()
{
  vc_getscm || return $?
  vc_epoch_$scm
}


vc__age()
{
  vc_getscm || return $?
  vc_age_$scm
}


vc_man_1__checkout='Checkout'
vc_flags__checkout=f
vc__checkout() # [Branch] [Remote]
{
  vc_getscm || return $?
  test -n "$1" || set -- "$(vc_branch)" "$2"
  test -n "$2" || set -- "$1" "$vc_rt_def"
  vc_checkout "$1" || return $?
}


vc_man_1__switch='Checkout with submodule deinit/init'
vc__switch() # [Branch] [Remote]
{
  vc_getscm || return $?
  test -n "$1" || error "branch expected" 1
  test "$1" = "$(vc_branch)" && return
  test -n "$2" || set -- "$1" "$vc_rt_def"
  {
      git submodule deinit . &&
      vc_checkout "$1" &&
      git submodule update --init --recursive
  } || return $?
}


vc_man_1__update='Fetch local from remote TODO: use gitflow config'
vc_flags__update=f
vc__update() # [vc_dir=$scriptpath] checkout [Branch] [Remote] [Action]
{
  vc_getscm || return $?
  test -n "$vc_sync" || vc_sync=0
  test -d "$vc_dir" && note "Running SCM $act for '$vc_dir'" || error vc-dir 1
  (
    test "$(pwd -P)" = "$vc_dir" || cd $vc_dir
    test -n "$1" || set -- "$(vc_branch)" "$2" "$3"
    test -n "$2" || set -- "$1" "$vc_rt_def" "$3"
    test -n "$3" || set -- "$1" "$2" "merge"
    {
      vc__checkout "$@" &&
      #git pull "$2" "$1" || return $?
      git fetch "$2" "$1" &&
      git $3 "$2/$1"
    } || return $?
    trueish "$vc_sync" && {
      git push "$2" "$1" || return $?
    }
  )
}

vc_man_1__update_from=''
vc_flags__update_from=f
vc__update_from() # [Remote] [Branch] [Action]
{
  vc_getscm || return $?
  test -n "$1" || set -- "$1" "$vc_rt_def" "$3"
  test -n "$2" || set -- "$(vc_branch)" "$2" "$3"
  test -n "$3" || set -- "$1" "$2" "merge"
  git fetch "$1" "$2" || return $?
  git $3 "$1/$2" || return $?
}

vc_flags__abort=f
vc__abort()
{
  test -n "$1" || set -- "merge"
  git $1 --abort
}



# Run over UP/DOWN-stream branchname pairs and show info:
# - wether branches have diverged
# - how many commits each has
# - for feature branches wether they are merged upstream and can be deleted
vc__gitflow()
{
  case "$1" in
    check|chk )
        test -z "$3" || error "surplus argument '$3'" 1
        test -n "$2" || set -- "$1" gitflow.tab
        test -e "$2" || error "missing gitflow file" 1
        note "Reading from '$2'"
        read_nix_style_file "$2" | while read -r upstream downstream isfeature
        do
          test -n "$upstream" -a -n "$downstream" || continue
          test -n "$upstream" || error "Missing upstream $downstream"
          test -n "$downstream" || error "Missing downstream $upstream"
          test -n "$isfeature" || isfeature=true

          vc__git_branch_exists "refs/heads/$upstream" || {
            error "$non_branch_err '$upstream $downstream $isfeature'" &&
              continue
          }

          vc__git_branch_exists "refs/heads/$downstream" || {
            error "$non_branch_err '$upstream $downstream $isfeature'" &&
              continue
          }

          new_at_up=$(echo $(git log --oneline $downstream..$upstream | wc -l))
          new_at_down=$(echo $(git log --oneline $upstream..$downstream | wc -l))
          m="$(git merge-base $upstream $downstream)"

          test "$m" = "$(git rev-parse $upstream)" -o "$m" = "$(git rev-parse $downstream)" && {
            echo "ok: $upstream - $downstream"
          } || {
            echo "diverged: $upstream .. $downstream"
          }
          test $new_at_down -eq 0 && {
            trueish "$isfeature" && {
              echo "downstream '$downstream' has no commits and could be removed"
            } || true
          } ||
            echo "$new_at_down commits '$upstream' <- '$downstream' "

          test $new_at_up -eq 0 ||
            echo "$new_at_up commits '$upstream' -> '$downstream' "
        done
        for branch in $(vc__branches)
        do
          grep -qF "$branch" "$2" ||
            error "Missing gitflow for '$branch'"
        done
      ;;
    * )
        error "? '$1'"
      ;;
  esac
}
vc__gf()
{
  vc__gitflow "$@"
}
vc_als__gf=gitflow



# TODO: add other backup commands, like htd backup. modelled after brixadmin
# unversioned-files.
# - Copy with relative path as given into first UNVERSIONED_FILES dir
# - Check into git annex, git, bzr, or poor mans checksum SCM
# - Check any matching path out of repo
#
#project_id()
#{
#  test -d .git && {
#    basename $(git config --get remote.origin.url) .git
#  } || {
#    test "$(hostname -s)" = "jenkins" && {
#      basename $(dirname $PWD)
#    } || {
#      basename $PWD
#    }
#  }
#}
#  test -n "$project" || export project="$(cmd_project_id)"
#  export UNVERSIONED_FILES=../unversioned-files/$project
#
#
## list files in unversioned dir for current project
#vc__unversioned()
#{
#  test -z "$2" || err "surplus arguments" 1
#  test_dir $UNVERSIONED_FILES/$1 || return 1
#  test -x "$(which tree)" && {
#    tree -C "$UNVERSIONED_FILES/$1"
#  } || {
#    echo "$UNVERSIONED_FILES/$1:"
#    find $UNVERSIONED_FILES/$1
#  }
#}
#
#vc__backup_unversioned()
#{
#  test -z "$2" || err "surplus arguments" 1
#  test -n "$1" && {
#    # backup path at argument
#    for p in $@
#    do
#      test -e "$1" || err "Not an existing path" 1
#      test -f "$1" && {
#        mkdir -p $(dirname $UNVERSIONED_FILES/$p)
#        cp -v "$p" "$(dirname $UNVERSIONED_FILES/$p)/"
#      } || test -d "$1" && {
#        vc__backup_unversioned_from_dir $1
#      }
#    done
#  } || {
#    # no argument: backup all GIT cleanable files
#    vc__backup_unversioned_from_dir "$PWD" || return $?
#  }
#}
#
#vc__backup_unversioned_from_dir()
#{
#  test -n "$1" || err "expected dir argument" 1
#  test -n "$UNVERSIONED_FILES" || error UNVERSIONED_FILES= 1
#  test -d "$(dirname $UNVERSIONED_FILES)" || error "No dir '$UNVERSIONED_FILES'" 1
#  test -d "$UNVERSIONED_FILES" || mkdir $UNVERSIONED_FILES
#
#  pwd=$PWD
#  cd $UNVERSIONED_FILES/..
#  git annex unlock ./$project || error "projdir" 1
#  cd "$pwd"
#
#  git ls-files --others "$1" | while read p
#  do
#    test_file $p || err "Not a file: $p" 1
#    mkdir -p $(dirname $UNVERSIONED_FILES/$p)
#    cp -v "$p" "$(dirname $UNVERSIONED_FILES/$p)/"
#  done
#
#  cd $UNVERSIONED_FILES
#  git annex add . || error "annex add" 1
#  git commit -m "Files from $project"
#  git annex lock . || error "projdir" 1
#  git annex sync
#  git annex copy --to simza
#  cd $pwd
#}
#
#vc__restore_unversioned()
#{
#  test -z "$2" || err "surplus arguments" 1
#  test_file $UNVERSIONED_FILES/$1 || return 1
#  cp -v $UNVERSIONED_FILES/$1 $1
#}
#
## list different files
#vc__diff_unversioned()
#{
#  test -z "$2" || err "surplus arguments" 1
#  test -n "$1" && p="$1" || p=.
#  diff -bqr $UNVERSIONED_FILES/$p $p
#}
#
#vc__vimdiff_unversioned()
#{
#  test -z "$2" || err "surplus arguments" 1
#  test -n "$1" && p="$1" || p=.
#  vimdiff $UNVERSIONED_FILES/$p $p
#}



vc_man_1__conflicts='Show current merge conflicts

    list | ls
      List conflicted filenames (using GIT diff)
    shoft | diff
      List source lines for each current merge conflict (all files).
    stat | stats
      List start/end line and total lines for merge conflicts (all files).
    diff-file [filename]
      Print source lines of all conflicts in file to stdout.
    stat-file [filename]
      Print start/end and other numbers per conflict found in file to stdout.
    show-for-marker <filename> <marker-line-nr>
      Show source lines at stdout, and stats on stderr.
      Set env `source=false` to silence.
'
vc__conflicts()
{
  test -n "$1" || set -- list
  case "$1" in

    list|ls )
        git diff --name-only --diff-filter=U
      ;;

    stat|stats )
        vc__conflicts list | while read filename
        do
          vc__conflicts stat-file $filename
        done
      ;;

    show|diff )
        vc__conflicts list | while read filename
        do
          vc__conflicts -show-lines-for-file $filename
        done
      ;;

    count ) shift
        vc__conflicts list | while read filename
        do
          note "$filename: $( vc__conflicts count-file $filename ) conflicts"
        done
      ;;

    count-file ) shift
        test -f "$1" && local filename=$1 || error "Filename expected" 1
        grep -n '^=======$' $filename | count_lines
      ;;

    stat-file ) shift
        test -f "$1" && local filename=$1 || error "Filename expected" 1
        grep -n '^=======$' $filename | cut -d ':' -f 1 | while read middle_lnr
        do
          vc__conflicts -find-for-marker "$filename" $middle_lnr || continue
          vc__conflicts -stat-for-marker-env
        done
      ;;

    show-file | diff-file | -show-lines-for-file ) shift
        test -f "$1" && local filename=$1 || error "Filename expected" 1
        note "Conflicts in $filename"
        grep -n '^=======$' $filename | cut -d ':' -f 1 | while read middle_lnr
        do
          source=true vc__conflicts show-for-marker "$filename" $middle_lnr ||
            continue
        done
      ;;

    show-for-marker ) shift
        test -f "$1" && local filename=$1 || error "Filename expected" 1
        vc__conflicts -find-for-marker "$@" || return
        vc__conflicts -show-for-marker-env
      ;;

    -find-for-marker ) shift
        # NOTE: Use the middle marker as starting point, this may give
        # problems in a few cases just warn and continue if no start/end
        # is found beyond/before the previous/next end/start marker line.

        test -f "$1" && local filename=$1 || error "Filename expected" 1
        test -n "$2" || error "Marker line expected" 1
        start= line=$(( $2 - 1 ))

        while test $line -gt 0
        do
          source_line $filename $line | grep -q '^<<<<<<<.*$' && {
            start=$line
            break
          } || {

            # dont cross another conflict-marker
            source_line $filename $line |
              grep -q '^\(=======\|>>>>>>>.*\)$' &&
              break

            line=$(( $line - 1 ))
          }
        done

        test -n "$start" ||
          return 1

        end= filelen=$(count_lines $filename)
        line=$(( $2 + 1 ))
        while test $line -le $filelen
        do
          source_line $filename $line | grep -q '^>>>>>>>.*' && {
            end=$(( $line + 1 ))
            break
          } || {

            # dont cross another conflict-marker
            source_line $filename $line |
              grep -q '^\(=======\|<<<<<<<.*\)$' &&
              break

            line=$(( $line + 1 ))
          }
        done

        test -n "$end" || {
          warn "Start/Middle but no end found at $filename:$2 (start: $1)"
          return 1
        }
      ;;

    -show-for-marker-env )
        test -n "$diff" || local diff=/tmp/vc-conflicts.$(get_uuid)
        { source_lines $filename $start $end ||
            error "source'ing source from $filename $start-$end" 1
        } | { trueish "$source" &&
                { tee $diff || error "tee'ing $diff" 1; } ||
                { cat > $diff; }
        }
        note "$filename: $start - $end ($middle_lnr): $( count_lines $diff ) lines"
      ;;

    -stat-for-marker-env )
        local diff=/tmp/vc-conflicts.$(get_uuid)
        source=false vc__conflicts -show-for-marker-env
        echo "$filename:$start-$end:middle=$middle_lnr:line_count=$( count_lines $diff )"
      ;;

    * ) error "? '$1'" 1 ;;
  esac
}


vc_man_1__cleanup_local='Remove local branches not in gitflow'
vc__cleanup_local()
{
  git show-ref --heads | cut -c53- | while read branch ; do
    grep -F "$branch" gitflow.tab ||
        git branch -d $branch
  done
}


vc_man_1__sync='
'
vc__sync()
{
  test -n "$vc_rebase" || vc_rebase=0
  test -n "$vc_force" || vc_force=0
  trueish "$vc_rebase" && update=rebase || update=pull
  trueish "$vc_force" %% push_f=-f || push_f=
  local current_branch="$(git rev-parse --abbrev-ref HEAD)"
  git show-ref --heads | cut -c53- | while read branch ; do
    git remote | while read remote ; do
      git checkout $branch ||
        warn "Checkout $branch failed" 1
      git $update $remote $branch && {
        git push $push_f $remote $branch
      } || {
        warn "Rebase on $remote/$branch failed" 1
      }
    done
  done
  git checkout $current_branch
}


vc_man_1__stats='Count files (tracked, untracked, ignored and subgroups)
'
vc__stats()
{
  test -n "$1" || set -- "." "$2"
  test -n "$2" || set -- "$1" "  "
  local scm= scmdir=
  vc_getscm "$1" || return $?
  vc_stats "$@"
}


vc__git_annex_list() # remote..
{
  vc_git_annex_list $(for remote in "$@"; do printf -- "-i $remote "; done)
}


vc__info()
{
  test -n "$1" || set -- "." "$2"
  test -n "$2" || set -- "$1" "  "
  local scm= scmdir=
  vc_getscm "$1" || return $?
  test -n "$scm" || {
      note "No checkout at '$1'"
  }
  vc_info "$@"
  note "See help for info on status tokens"
}


vc_man_1__dist='Push commits to remotes.
If none given set to Package-Dist, or all remotes'
vc_flags__dist=q
vc__dist() # [Remotes]
{
  test -n "$1" || set -- $package_dist
  test -n "$1" || set -- $( package_sh_list "$PACK_SH" "dist" )
  test -n "$1" || set -- $(vc__remotes | lines_to_words)

  note "distributing to '$*'..."
  vc_dist_inner() { git push "$1" --all ; }
  p= s= act=vc_dist_inner foreach_do "$@"
}


vc_man_1__update_local='Update local branches from remote'
vc_flags__update_local=f
vc__update_local()
{
  vc_getscm || return $?
  test -n "$1" || set -- "$vc_rt_def"
  vc_fetch "$1" || return $?
  local startbranch="$(vc_branch)"
  for branch in $( vc_branches )
  do
      test -n "$branch" || continue ;
      vc__switch "$branch" &&
      vc__update_from "$1" "$branch" "rebase" || {
        vc__abort && touch $failed
      }
  done || touch $failed
  vc__switch $startbranch
}


vc__blame()
{
  vc_getscm || return $?
  test -n "$1" || error "Expected existing file '$1'" 1
  vc_blame "$@"
}


vc__up()
{
  false # TODO: take current branch, find upstream(s) in vcflow and update (merge/rebase)
}

vc__down()
{
  false # XXX: local repo, contrary to up?
  # Ie. like undo-commit, but go to last merge/rebase
}


# -- vc box insert sentinel --


# ----

# Script main functions

# TODO: move vctmp.sh back in here/cleanup

main-init-env \
  INIT_ENV= INIT_LIB=std\ sys\ src\ sys-htd\ os\ str\ log\ match\ main\ vc\ vc-htd\ ctx-std

main-init \
  init_sh_libs=os\ sys\ str\ log \
  true "${CWD:="$scriptpath"}" \
  true "${SUITE:="Main"}" \
  true "${_ENV:="$scriptpath/.meta/package/envs/main.sh"}" \
  test ! -e $_ENV || { source $_ENV || return; }\
  test ! -z "${SCRIPTPATH-}" || return

main-load \
  local __load_lib=1 cwd="$PWD" \
  # FIXME: sh autocompletion \
  #. ~/.conf/bash/git-completion.bash \
 \
  test -n "${hnid-}" || hnid="$(hostname -s | tr 'A-Z.-' 'a-z__')" \
  test -n "${uname-}" || uname="$(uname -s | tr '[:upper:]' '[:lower:]')" \
  test -n "${vc_dir-}" || vc_dir=$PWD \
  test -n "${vc_dir-}" || vc_dir=$scriptpath \
  test -n "${vc_br_def-}" || vc_br_def=master \
  test -n "${vc_rt_def-}" || vc_rt_def=origin \
  #statusdir.sh assert vc_status > /dev/null || error vc_status 1 \
  gtd="$(vc_gitdir "$vc_dir")" \
 \
  # See ignores.rst for info on Global/Purgeable,Cleanable and Droppable \
  test -n "${vc_clean_gl-}" || { \
    test -e .gitignore-clean && export vc_clean_gl=.gitignore-clean \
    test -e ~/.gitignore-clean-global \\
      && export vc_clean_gl="${vc_clean_gl-}${vc_clean_gl+" "}$HOME/.gitignore-clean-global"  \
  } \
  test -n "${vc_temp_gl-}" || { \
    test -e .gitignore-temp \\
      && export vc_temp_gl=.gitignore-temp \
    test -e ~/.gitignore-temp-global \\
      && export vc_temp_gl="${vc_temp_gl-}${vc_temp_gl+" "}$HOME/.gitignore-temp-global" \
  } \
 \
  # TODO: list of dirs (checkouts, annexes) to retrieve/store files \
  test -n "${UNVERSIONED_FILES-}" || { \
    #test -e /srv/annex-local \
    UNVERSIONED_FILES=$( for dir in /srv/backup-local /srv/archive-local \\
        /srv/archive-old-local /srv/htdocs-local; do \
      test -e $dir && echo "$dir" || continue; done ) \
  }

main-load-flags \
    f ) \
        # Preset name to subcmd failed file placeholder \
        failed=$(setup_tmpf .failed) \
      ;; \
 \
    C ) \
        # Return cached value. Validate based on timestamp. \
        C= c= \
        C_exptime=$(try_value ${subcmd} C_exptime) \
        C_validate="$(try_value ${subcmd} C_validate)" \
        stat_key C >/dev/null \
        C="$(statusdir.sh get $C_key)" \
        C_mtime= \
        c_mtime=$(eval $C_validate 2>/dev/null) \
        ( test -n "$c_mtime" && C_cached $c_mtime ) && { \
          echo $C \
          debug "cached" \
          exit 0 \
        } || debug "cache:$?" \
      ;; \
 \
    q ) # set if not set, dont update and eval package main env \
        test -n "${PACK_SH-}" -a -e "${PACK_SH-}" || { \
            test -n "$PACKMETA" -a -e "$PACKMETA" && \
                note "Using package '"'"\$PACKMETA"'"'" || \
                error "No local package" 5 \
            package_lib_set_local "$CWD" || \
                error "Setting local package ($CWD)" 6 \
        } \
 \
        # Evaluate package env \
        . $PACK_SH || error "local package" 7 \
 \
        test "$package_type" = "application/vnd.org.wtwta.project" || \
                error "Project package expected (not $package_type)" 4 \
        test -n "$package_env" || export package_env=". $PACK_SH" \
        debug "Found package '"'"\$package_id"'"'" \
      ;;

main-unload-flags \
 \
    C ) \
        # Update cached value \
        test -z "$c" || { \
          test "$C" = "$c" \\
            || { \
              statusdir.sh set $C_key "$c" $exptime 2>&1 >/dev/null \
              statusdir.sh set $C_key:time $c_mtime $C_exptime 2>&1 >/dev/null \
            } \
          } \
      ;;



main-epilogue \
# Id: script-mpe/0.0.4-dev vc.sh
