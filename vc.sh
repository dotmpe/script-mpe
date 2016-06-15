#!/bin/sh
#
# SCM util functions and pretty prompt printer for Bash, GIT
# TODO: other SCMs, BZR, HG, SVN (but never need them so..)
# XXX: more in projectdir.sh in private repo
#
#HELP="vc - version-control helper functions "
vc_src="$_"

set -e


vc_load()
{
  local __load_lib=1 cwd="$(pwd)"

  # FIXME: sh autocompletion
  #. ~/.conf/bash/git-completion.bash

  test -n "$hnid" || hnid="$(hostname -s | tr 'A-Z.-' 'a-z__')"
  test -n "$uname" || uname=$(uname)

  . $scriptdir/util.sh
  . $scriptdir/main.sh
  . $scriptdir/match.lib.sh

  str_load

  statusdir.sh assert vc_status > /dev/null || error vc_status 1

  gtd=$(__vc_gitdir $cwd)


  # Look at run flags for subcmd
  for x in $(try_value "${subcmd}" run | sed 's/./&\ /g')
  do
    debug "${base} load ${subcmd} $x"
    case "$x" in

    f )
        # Preset name to subcmd failed file placeholder
        failed=$(setup_tmp .failed)
      ;;

    C )
        # Return cached value. Validate based on timestamp.
        C= c=
        C_exptime=$(try_value ${subcmd} C_exptime)
        C_validate="$(try_value ${subcmd} C_validate)"
        stat_key C >/dev/null
        C="$(statusdir.sh get $C_key)"
        C_mtime=
        c_mtime=$(eval $C_validate 2>/dev/null)
        ( test -n "$c_mtime" && C_cached $c_mtime ) && {
          echo $C
          debug "cached"
          exit 0
        } || debug "cache:$?"
      ;;
    esac
  done
}

C_cached()
{
  test -n "$C" || return 1
  C_mtime=$(statusdir.sh get $C_key:time || return $?)
  test -n "$C_mtime" || return 2
  test $C_mtime -ge $c_mtime || return 3
}

vc_unload()
{
  for x in $(try_value "${subcmd}" run | sed 's/./&\ /g')
  do
    debug "${base} unload ${subcmd} $x"
    case "$x" in

    C )
        # Update cached value
        test -z "$c" || {
          test "$C" = "$c" \
            || {
              statusdir.sh set $C_key "$c" $exptime 2>&1 >/dev/null
              statusdir.sh set $C_key:time $c_mtime $C_exptime 2>&1 >/dev/null
            }
          }
      ;;
  esac; done
  clean_failed
}


vc_usage()
{
	echo 'Usage: '
	echo "  $scriptname <cmd> [<args>..]"
}

vc__commands()
{
	echo 'Commands: '
	echo '  print-all <path>        Dump some debug info on given (versioned) paths'
	echo '  ps1                     Print PS1'
	echo '  screen'
  echo '  ls-gitroots             List all GIT checkouts (roots only) below the current dir.'
	echo '  ls-errors               '
	echo '  mtime'
	echo '  flush'
	echo '  print-all'
	echo '  prompt-command'
	echo '  list-submodules'
	echo '  gh                      Clone from github'
	echo '  largest-objects'
	echo '  path-for-object'
	echo '  list-object'
	echo '  object-contents'
	echo '  excludes'
	echo '  ufx'
	echo '  excluded'
	echo '  annex-unused'
	echo '  annex-show-unused'
	echo '  annex-clear-unused'
	echo '  contains'
	echo '  annex-contains'
	echo '  list-prefixes           '
	echo '  list-subrepos           XXX: List all repositories below, excluding submodules. '
	echo '  projects                XXX: list remotes in projectdir'
	echo '  remotes                 List remotes in repo. '
	echo '  regenerate              Regenerate local excludes. '
	echo '  annex-local             Find or create remote annex repo in $ANNEX_DIR'
	echo ''
	echo 'Other commands: '
	echo '  -e|edit                 Edit this script.'
	echo '  help                    Give a combined usage, command and docs. '
	echo '  docs                    Echo manual page. '
	echo '  commands                Echo this comand description listing.'
}

vc__help()
{
	vc_usage
	echo ''
	vc__commands
	echo ''
	vc__docs
}

vc__docs()
{
	echo "See htd and dckr for other scripts"
}


vc__version()
{
	# no version, just checking it goes
	echo 0.0.0
}
vc___v() { c__version; }


vc__edit()
{
	[ -n "$1" ] && fn=$1 || fn=$(which $scriptname)
	[ -n "$fn" ] || fn=$(which $scriptname.sh)
	[ -n "$fn" ] || error "Nothing to edit" 1
	$EDITOR $fn
}
vc___e() { vc__edit; }


### Internal functions

homepath()
{
    test -n "$1" || exit 212
    test -n "$HOME" || exit 213
	# Bash, BSD Sh?
    str_replace_start "$1" "$HOME" "~"
}

# Flags legenda:
#
# __vc_git_flags : cbwisur
# c: ''|'BARE:'
# b: branchname
# w: '*'
# i: '+'|'#'
# s: '$'
# u: '~'
#

__vc_bzrdir()
{
  local cwd="$(pwd)"
  (
    cd "$1"
    root=$(bzr info 2> /dev/null | grep 'branch root')
    if [ -n "$root" ]; then
      echo $root/.bzr | sed 's/^\ *branch\ root:\ //'
    fi
  )
}

# __vc_gitdir accepts 0 or 1 arguments (i.e., location)
# returns absolute location of .git repo
__vc_gitdir()
{
  test -n "$1" || set -- $(pwd -P)
	test -d "$1/.git" && {
		echo "$1/.git"
  } || (
    cd "$1"
    git rev-parse --git-dir
  )
}

# checkout dir
# for regular checkouts, the parent dir
# for modules, one level + prefix levels higher
__vc_git_codir()
{
  git="$(__vc_gitdir "$1")"

  fnmatch "*/.git" "$git" \
    || while true
      do
        git="$(dirname "$git")"
        fnmatch "*/.git" "$git" && break
      done

  dirname "$git"
}

# __vc_git_flags accepts 0 or 1 arguments (i.e., format string)
# returns text to add to bash PS1 prompt (includes branch name)
__vc_git_flags()
{
  local pwd="$(pwd)"
	#local g="$1"
  #[ -n "$g" ] ||
  g="$(__vc_gitdir "$pwd")"
	if [ -e "$g" ]
	then

    test "$(echo $g/refs/heads/*)" != "$g/refs/heads*" || {
      echo "(git:unborn)"
      return
    }

		cd $pwd
		local r
		local b
		if [ -f "$g/rebase-merge/interactive" ]; then
			r="|REBASE-i"
			b="$(cat "$g/rebase-merge/head-name")"
		elif [ -d "$g/rebase-merge" ]; then
			r="|REBASE-m"
			b="$(cat "$g/rebase-merge/head-name")"
		else
			if [ -d "$g/rebase-apply" ]; then
				if [ -f "$g/rebase-apply/rebasing" ]; then
					r="|REBASE"
				elif [ -f "$g/rebase-apply/applying" ]; then
					r="|AM"
				else
					r="|AM/REBASE"
				fi
			elif [ -f "$g/MERGE_HEAD" ]; then
				r="|MERGING"
			elif [ -f "$g/BISECT_LOG" ]; then
				r="|BISECTING"
			fi

			b="$(git symbolic-ref HEAD 2>/dev/null)" || {

				b="$(
				case "${GIT_PS1_DESCRIBE_STYLE-}" in
				(contains)
					git describe --contains HEAD ;;
				(branch)
					git describe --contains --all HEAD ;;
				(describe)
					git describe HEAD ;;
				(* | default)
					git describe --exact-match HEAD ;;
				esac 2>/dev/null)" ||

				b="$(cut -c1-7 "$g/HEAD" 2>/dev/null)..." ||
				b="unknown"
				b="($b)"
			}
		fi

		local w= i= s= u= c=

		if [ "true" = "$(git rev-parse --is-inside-git-dir 2>/dev/null)" ]; then
			if [ "true" = "$(git rev-parse --is-bare-repository 2>/dev/null)" ]; then
				c="BARE:"
			else
				b="GIT_DIR!"
			fi
		elif [ "true" = "$(git rev-parse --is-inside-work-tree 2>/dev/null)" ]; then
			if [ -n "${GIT_PS1_SHOWDIRTYSTATE-}" ]; then
				if [ "$(git config --bool bash.showDirtyState)" != "false" ]; then
					git diff --no-ext-diff --ignore-submodules \
						--quiet --exit-code || w='*'
					if git rev-parse --quiet --verify HEAD >/dev/null; then
						git diff-index --cached --quiet \
							--ignore-submodules HEAD -- || i="+"
					else
						i="#"
					fi
				fi
			fi
			if [ -n "${GIT_PS1_SHOWSTASHSTATE-}" ]; then
				git rev-parse --verify refs/stash >/dev/null 2>&1 && s="$"
			fi

			if [ -n "${GIT_PS1_SHOWUNTRACKEDFILES-}" ]; then
				if [ -n "$(git ls-files --others --exclude-standard)" ]; then
					u="~"
				fi
			fi
		fi

		repotype="$c"
		branch="${b##refs/heads/}"
		modified="$w"
		staged="$i"
		stashed="$s"
		untracked="$u"
		state="$r"

		x=
		rg=$g
		test -f "$g" && {
			g=$(dirname $g)/$(cat .git | cut -d ' ' -f 2)
		}
		if [ -d $g/annex ]; then
			#x="(annex:$(echo $(du -hs $g/annex/objects|cut -f1)))$c"
			x="(annex)$c"
		fi

		if [ -n "${2-}" ]; then
			printf "$2" "$c$x${b##refs/heads/}$w$i$s$u$r"
		else
			printf " (%s)" "$c$x${b##refs/heads/}$w$i$s$u$r"
		fi

		cd $cwd
	fi
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
  test -n "$1" || set -- "$(pwd)"
	test -d "$1" || err "No such directory $1" 3

	local w short repo sub

  local pwd="$(pwd)"

	realcwd="$(cd $1; pwd -P)"
	short="$(homepath "$1")"
	test -n "$short" || err "homepath" 1

	local git="$(__vc_gitdir "$realcwd")"
	local bzr=$(__vc_bzrdir "$realcwd")

	if [ -n "$git" ]; then

    test -e "$git/refs/heads/master" || {
      echo "$realcwd (git:unborn)"
      return
    }

		checkoutdir="$(cd $realcwd; git rev-parse --show-toplevel)"

		[ -n "$checkoutdir" ] && {

			rev="$(cd $realcwd; git show "$checkoutdir" | grep '^commit' \
			  | sed 's/^commit //' | sed 's/^\([a-f0-9]\{9\}\).*$/\1.../')"
			sub="${realcwd##$checkoutdir}"

		} || {

			realgitdir="$(cd "$git"; pwd -P)"
			rev="$(cd $realcwd; git show . | grep '^commit'|sed 's/^commit //' | sed 's/^\([a-f0-9]\{9\}\).*$/\1.../')"
			realgit="$(basename $realgitdir)"
			sub="${realcwd##$realgit}"
		}

		short="${short%$sub}"
		echo "$short" $(__vc_git_flags $realcwd "[git:%s $rev]")$sub

	else if [ "$bzr" ]; then
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
	#	local r=$(svn info | sed -n -e '/^Revision: \([0-9]*\).*$/s//\1/p' )
	#	local s=""
	#	local sub=
	#	if [ "$(svn status | grep -q -v '^?')" ]; then s="${s}*"; fi
	#	if [ -n "$s" ]; then s=" ${s}"; fi;
	#	echo "$short$PSEP [svn:r$r$s]$sub"
	else
		echo $short
	fi;fi;
	cd $cwd
}

__vc_screen ()
{
	local w short repo sub

  test -n "$1" || set -- "$(pwd)"

	realcwd="$(pwd -P)"
	short=$(homepath "$1")

	local git=$(__vc_gitdir "$1")
	if [ "$git" ]; then

    test -e "$git/refs/heads/master" || {
      echo "$(pwd) (git:unborn)"
      return
    }
		realroot="$(git rev-parse --show-toplevel)"
		[ -n "$realroot" ] && {
			rev="$(git show "$realroot" | grep '^commit'|sed 's/^commit //' | sed 's/^\([a-f0-9]\{9\}\).*$/\1.../')"
			sub="${realcwd##$realroot}"
		} || {
			realgitdir="$(cd "$git"; pwd -P)"
			rev="$(git show . | grep '^commit'|sed 's/^commit //' | sed 's/^\([a-f0-9]\{9\}\).*$/\1.../')"
			realgit="$(basename $realgitdir)"
			sub="${realcwd##$realgit}"
		}
		echo $(basename "$realcwd") $(__vc_git_flags $git "[git:%s $rev]")
	else
		echo "$short"
	fi
}


__vc_pull ()
{
	cd "$1"
	local git=$(__vc_gitdir)
	local bzr=$(__vc_bzrdir)
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
	local git=$(__vc_gitdir)
	local bzr=$(__vc_bzrdir)
	if [ "$git" ]; then
		git push origin master;
	else if [ "$bzr" ]; then
		bzr push;
#	else if [ -d ".svn" ]; then
#	    svn
	fi; fi;
}


# get a/the vendor/project ID's
# many possible ways to get it, defaults to something github-ish.
# But let .package.sh decide method
# must be called from within checkout base dir
__vc_gitrepo()
{
  test -e .git || err "not a checkout" 240
  test -e .package && . .package.sh

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
          s/^.*:([A-Za-z0-9_-]*)\/([A-Za-z0-9_-]*)(.git)?/\1\/\2/'
      ;;

    * )
        error "Illegal vc gitrepo method '$1'" 1
      ;;
  esac
}


list_gitpaths()
{
	d=$1
	[ -n "$d" ] || d=.
	note "Starting find in '$d', this may take a bit initially.."
	find $d -iname .git -not -ipath '*.git/*' | while read gitpath mode
	do
		test -n "$gitpath" -a "$gitpath" != ./.git \
			&& echo $gitpath
	done
}

vc_ls_gitroots()
{
	list_gitpaths $1 | while read gitpath
	do dirname $gitpath
	done
}

vc_ls_errors()
{
	list_gitpaths $1 | while read gitpath
	do
		[ -d "$gitpath" ] && {
			git_info $gitpath > /dev/null || {
				error "in info from $gitpath, see previous."
			}
		} || {
			gitdir=$(__vc_gitdir $(dirname $gitpath))
			echo $gitdir | grep -v '.git\/modules' > /dev/null && {
				# files should be gitlinks for submodules
				warn "for  $gitpath, see previous. Broken gitlink?"
				continue
			}
		}
	done
}


### Command Line handlers

vc_run__stat=f
vc__stat()
{
  test -n "$1" || set -- .
  __vc_status "$1" || return $?
}
# TODO: alias
vc_als__status=stat


vc__bits()
{
  __vc_status || return $?
}


# TODO: vcflags
vc__gitflags()
{
  __vc_git_flags "$@" || return $?
}


vc_man_1__ps1="Print VC status in the middle of PWD. ".
vc_run__ps1=x
vc_spc__ps1="ps1"
vc__ps1()
{
  test -n "$gtd" || { pwd; return; }
  c="$(__vc_status "$(pwd)" || return $?)"
  echo "$c"
}
vc_C_exptime__ps1=0
vc_C_validate__ps1="vc__mtime \$gtd"


vc_man_1__screen="Print VC status in the middle of PWD. ".
vc_run__screen=x
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
    filemtime $1/index
    filemtime $1/HEAD
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

# print all fuctions/results for paths in arguments
vc__print_all()
{
	for path in $@
	do
		[ ! -e "$path" ] && continue
		echo vc-status[$path]=\"$(__vc_status "$path")\"
	done
}


# special updater (for Bash PROMPT_COMMAND)
vc__prompt_command()
{
  test -n "$1" -a -d "$1" \
    || error "No such directory '$1'" 3

  # cache response in file
  pwdref="$(echo "$1" | tr '/' '-' )"
  cache="$(statusdir.sh assert-dir vc prompt-command $pwdref)"

  test ! -e "$cache" -o $1/.git -nt "$cache" && {
    __vc_status $1 > "$cache"
  }

  cat "$cache"
}


vc__list_submodules()
{
  git submodule foreach | sed "s/.*'\(.*\)'.*/\1/"
}

vc_man_1__gh="Clone from Github to subdir, adding as submodule if already in checkout. "
vc_spc__gh="gh <repo> [<prefix>]"
vc__gh() {
  test -n "$1" || error "Need repo name argument" 1
  str_match "$1" "[^/]*" && {
    repo=dotmpe/$1; prefix=$1; } || {
    repo=$1; prefix=$(basename $1); }
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
      log "Adding submodule $giturl to $(pwd)/$prefix.."
      ${git} submodule add $giturl $prefix
      log "Added submodule $giturl to $(pwd)/$prefix"
    } || {
      # TODO: find/print root. then go there. see vc.sh
      error "Please recede to root and use prefix to add submodule" 1
    }
  } || {
    log "Cloning $giturl to $(pwd)/$prefix.."
    ${git} clone $giturl $prefix
    log "Cloned $giturl to $(pwd)/$prefix"
  }
}

vc__largest_objects()
{
  test -n "$1" || set -- 10
  $scriptdir/git-largest-objects.sh $1
}

# list commits for object sha1
vc__path_for_object()
{
  test -n "$1" || error "provide object hash" 1
  while test -n "$1"
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

# print tree, blob, commit, etc. objs
vc__list_objects()
{
  git verify-pack -v .git/objects/pack/pack-*.idx
}

vc__object_contents()
{
  git cat-file -p $1
}

vc_man_1__excludes="List path ignore patterns"
vc__excludes()
{
  # (global) core.excludesfile setting
  global_excludes=$(echo $(git config --get core.excludesfile))
  test ! -e "$global_excludes" || {
    note "Global excludes:"
    cat $global_excludes
  }

  note "Local excludes (repository):"
  cat .git/info/exclude | grep -v '^\s*\(#\|$\)'

  test -s ".gitignore" && {
    note "Local excludes"
    cat .gitignore
  } || {
    note "No local excludes"
  }
}

# List unversioned including ignored
vc__ufx()
{
  vc__excluded
}
vc__excluded()
{
  # list paths not in git (including ignores)
  git ls-files --others --dir
  # XXX: need to add prefixes to returned paths:
  pwd=$(pwd)
  git submodule | while read hash prefix ref
  do
    path=$pwd/$prefix
    test -e $path/.git || {
      warn "Not a checkout: ${path}"
      continue
    }
    ( note $path:;cd $path && vc__excluded )
  done
}

# List all unversioned excluding ignored
vc__uf()
{
  vc__unversioned_files
}
vc__unversioned_files()
{
  # list cruft (not versioned and not ignored)
  git ls-files --others --exclude-standard
  # XXX: need to add prefixes to returned paths:
  pwd=$(pwd)
  git submodule | while read hash prefix ref
  do
    path=$pwd/$prefix
    test -e $path/.git || {
      warn "Not a checkout: ${path}"
      continue
    }
    ( cd $path && vc__unversioned_files )
  done
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
  c_annex_unused | while read num key
  do
    echo "GIT log for '$key'"
    git log --stat -S"$key"
  done
}

vc__annex_clear_unused()
{
  test -z "$1" && {
    local cnt
    cnt="$(c_annex_unused | tail -n 1 | cut -f 1 -d ' ')"
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
    git annex move --unused --to $1
  }
}

vc__contains()
{
  test -n "$1" || error "expected file path argument" 1
  test -f "$1" || error "not a file path argument '$1'" 1
  test -n "$2" || set -- "$1" "."
  test -z "$3" || error ""

  sha1="$(git hash-object "$1")"
  info "SHA1: $sha1"

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
  info "SHA256E key glob: $keyglob"
  { find $2 -ilname $keyglob | while read path; do echo $path;ls -la $path; done;
  } || warn "Found nothing for '$keyglob'"
}

# List submodule prefixes
vc__list_prefixes()
{
  git submodule foreach | sed "s/.*'\(.*\)'.*/\1/"
}

# List all nested repositories, excluding submodules
# XXX this does not work properly, best use it from root of repo
# XXX: takes subdir, and should in case of being in a subdir act the same
vc__list_subrepos()
{
  local cwd=$(pwd)
  basedir="$(dirname "$(__vc_gitdir "$1")")"
  test -n "$1" || set -- "."

  cd $basedir
  vc__list_prefixes > /tmp/vc-list-prefixes
  cd $cwd

  find $1 -iname .git | while read path
  do
    # skip root
    #test -n "$(realpath "$1/.git")" != "$(realpath "$path")" || continue

    # skip proper submodules
    match_grep_pattern_test "$(dirname "$path")" || continue
    grep_pattern="$p_"
    grep -q "$grep_pattern" /tmp/vc-list-prefixes && {
      continue
    } || {
      echo "$(dirname $path)"
    }
  done
#    git submodule foreach 'for remote in "$(git remote)"; do echo $remote; git
#    config remote.$remote.url  ; done'
}

vc__projects()
{
  test -f projects.sh || touch projects.sh

  cwd=$(pwd)
  pwd=$(pwd -P)

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
    cd $cwd
  done
}

vc__remotes()
{
  git remote | while read remote
  do
    case "$1" in
      '')
        echo $remote $(git config remote.$remote.url);;
      sh|var)
        echo $remote=$(git config remote.$remote.url);;
      *)
        error "illegal $1" 1;;
    esac
  done
}

vc__list_local_branches()
{
  local pwd=$(pwd)
  test -z "$1" || cd $1
  git branch -l | sed -E 's/\*|[[:space:]]//g'
  test -z "$1" || cd $pwd
}

# regenerate .git/info/exclude
vc__regenerate()
{
  local excludes=.git/info/exclude

  test -e $excludes.header || backup_header_comment $excludes

  info "Resetting local GIT excludes file"
  read_nix_style_file $excludes | sort -u > $excludes.list
  cat $excludes.header $excludes.list > $excludes
  rm $excludes.list

  info "Adding other git-ignore files"
  for x in .gitignore-*
  do
    test -e $x || continue
    fnmatch "$x: text/*" "$(file --mime $x)" || continue
    echo "# Source: $x" >> $excludes
    read_nix_style_file $x >> $excludes
  done

  note "Local excludes successfully regenerated"
}

# Add/update annex-dir remote
# If in an annex checkout, get repo name, and add remote $ANNEX_DIR/<repo>.git
vc__annex_local()
{
  test -n "$ANNEX_DIR" || error "ANNEX_DIR empty" 1
  test -d "$ANNEX_DIR" || error "ANNEX_DIR is not a dir '$ANNEX_DIR'" 1

  git=$(__vc_git_codir)
  test -n "$git" || err "not a checkout" 230

  repo=$(__vc_gitrepo)
  test -n "$repo" || err "no repo found for CWD" 1

  test -e $ANNEX_DIR/$repo || {
    mkdir -p $(dirname $ANNEX_DIR/$repo)
    git clone $git $ANNEX_DIR/$repo
  }

  git config remote.annex-dir.url >/dev/null && {
    git remote set-url annex-dir $ANNEX_DIR/$repo
  } || {
    git remote add annex-dir $ANNEX_DIR/$repo
  }
}

# ----


### Main

vc_main()
{
  # Do something if script invoked as 'vc.sh'
  local scriptname=vc base="$(basename "$0" .sh)" \
    subcmd=$1

  case "$base" in $scriptname )

        test -n "$scriptdir" || \
            scriptdir="$(cd "$(dirname "$0")"; pwd -P)"
        export SCRIPTPATH=$scriptdir
        . $scriptdir/util.sh

        test -n "$verbosity" || verbosity=5

        local func=$(echo vc__$subcmd | tr '-' '_') \
            ext_sh_sub=

        type $func >/dev/null 2>&1 && {
          shift 1
          vc_load || return
          $func "$@" || return $?
          vc_unload || return
        } || {
          R=$?
          vc_load || return
          test -n "$1" && {
            vc__print_all "$@"
            exit $R
          } || {
            vc__print_all $(pwd)
            exit 0
          }
        }

      ;;

    * )
      echo "VC is not a frontend for $base ($scriptname)" 2>&1
      exit 1
      ;;

  esac
}


# Ignore login console interpreter
case "$0" in "" ) ;; "-"* ) ;; * )

  # Ignore 'load-ext' sub-command

  # XXX arguments to source are working on Darwin 10.8.5, not Linux?
  # fix using another mechanism:
  test -z "$__load_lib" || set -- "load-ext"
  case "$1" in load-ext ) ;; * )

        vc_main "$@"
      ;;

  esac ;;

esac

