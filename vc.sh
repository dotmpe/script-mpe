#!/bin/sh
#
# SCM util functions and pretty prompt printer for Bash, GIT
# TODO: other SCMs, BZR, HG, SVN (but never need them so..)
# XXX: more in projectdir.sh in private repo
#
#HELP="vc - version-control helper functions "
vc_source=$_


vc_load()
{
  local __load_lib=1
#. ~/.conf/bash/git-completion.bash

  . ~/bin/std.sh
  . ~/bin/match.sh load-ext
  statusdir.sh assert vc_status > /dev/null || error vc_status 1
}

vc_usage()
{
	echo 'Usage: '
	echo "  $scriptname <cmd> [<args>..]"
}

vc_commands()
{
	echo 'Commands: '
	echo '  print-all <path>                 Dump some debug info on given (versioned) paths'
	echo '  ps1                              Print PS1'
	echo '  prompt-command                   ...'
	echo ''
	echo 'Other commands: '
	echo '  -e|edit                          Edit this script.'
	echo '  help                             Give a combined usage, command and docs. '
	echo '  docs                             Echo manual page. '
	echo '  commands                         Echo this comand description listing.'
}

vc_help()
{
	vc_usage
	echo ''
	vc_commands
	echo ''
	vc_docs
}

vc_docs()
{
	echo "See htd and dckr for other scripts"
}


vc__v()
{
	c_version
}

vc_version()
{
	# no version, just checking it goes
	echo 0.0.0
}

vc_edit()
{
	[ -n "$1" ] && fn=$1 || fn=$(which $scriptname)
	[ -n "$fn" ] || fn=$(which $scriptname.sh)
	[ -n "$fn" ] || error "Nothing to edit" 1
	$EDITOR $fn
}
vc__e()
{
	vc_edit
}


### Internal functions

homepath()
{
	w="$1"
	echo "${w/#$HOME/~}"
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

__vc_bzrdir ()
{
	pushd "$1" >> /dev/null
	root=$(bzr info 2> /dev/null | grep 'branch root')
	if [ -n "$root" ]; then
		echo $root/.bzr | sed 's/^\ *branch\ root:\ //'
	fi
	popd >> /dev/null
}

# __vc_gitdir accepts 0 or 1 arguments (i.e., location)
# returns location of .git repo
__vc_gitdir ()
{
	#if [ -z "${1-}" ]; then
	#	if [ -n "${__vc_git_dir-}" ]; then
	#		echo "$__vc_git_dir"
	#	elif [ -d .git ]; then
	#		echo ".git"
	#	else
    #        cd $1
	#		git rev-parse --git-dir 2>/dev/null
	#	fi
	D="$1"
	[ -n "$D" ] || D=.
	if [ -d "$D/.git" ]; then
		echo "$D/.git"
	else
		pushd "$D" >> /dev/null
		git rev-parse --git-dir 2>/dev/null
		popd >> /dev/null
	fi
}

# __vc_git_flags accepts 0 or 1 arguments (i.e., format string)
# returns text to add to bash PS1 prompt (includes branch name)
__vc_git_flags ()
{
	local g="$1"
	[ -n "$g" ] || g="$(__vc_gitdir)"
	if [ -e "$g" ]
	then
		pushd $(dirname $g) >> /dev/null
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

		local w
		local i
		local s
		local u
		local c

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
						--quiet --exit-code || w="*"
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

		popd >> /dev/null
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
__vc_status ()
{
	local w short repo sub

	w="$1";
	pushd "$w" >> /dev/null
	realcwd="$(pwd -P)"
	short="$(homepath "$w")"

	local git="$(__vc_gitdir "$realcwd")"
	local bzr=$(__vc_bzrdir "$realcwd")

	if [ -n "$git" ]; then
		realroot="$(git rev-parse --show-toplevel)"
		[ -n "$realroot" ] && {
			rev="$(git show "$realroot" | grep '^commit'|sed 's/^commit //' | sed 's/^\([a-f0-9]\{9\}\).*$/\1.../')"
			sub="${realcwd##$realroot}"
			realgitdir=$realroot/.git
		} || {
			realgitdir="$(cd "$git"; pwd -P)"
			rev="$(git show . | grep '^commit'|sed 's/^commit //' | sed 's/^\([a-f0-9]\{9\}\).*$/\1.../')"
			realgit="$(basename $realgitdir)"
			sub="${realcwd##$realgit}"
		}
		short="${short%$sub}"
		echo "$short" $(__vc_git_flags $realgitdir "[git:%s $rev]")$sub
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
	popd >> /dev/null
}

# Helper for just path reference notation, no SCM bits
__pwd_ps1 ()
{
	local w short

	d="$1";
	[ -z "$d" ] && d="$(pwd)"
	[ ! -d "$d" ] && echo "No such directory $d" && exit 3
	realcwd="$(cd $d && pwd -P)"
	short=$(homepath $d)
	echo $short
}


# Wrapper for __vc_status stat sets argument default to current dirctory
# Return all info bits from __vc_status()
__vc_ps1 ()
{
	d="$1"
	[ -z "$d" ] && d="$(pwd)"
	[ ! -d "$d" ] && echo "No such directory $d" && exit 3
	__vc_status "$d"
}

__vc_screen ()
{
	local w short repo sub

	w="$1";
	[ -z "$w" ] && w="$(pwd)"

	realcwd="$(pwd -P)"
	short=$(homepath "$w")

	local git=$(__vc_gitdir "$w")
	if [ "$git" ]; then
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
		echo $(basename "$realcwd") $(__vc_git_flags $realgitdir "[git:%s $rev]")
	else
		echo "$short"
	fi
}

__vc_git_ps1()
{
    __vc_git_flags $@
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

list_git_checkouts()
{
	list_gitpaths $1 | while read gitpath
	do dirname $gitpath
	done
}

list_errors()
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

# print all fuctions/results for paths in arguments
vc_print_all()
{
	for path in $@
	do
		[ ! -e "$path" ] && continue
		echo -e vc-status[$path]=\"$(__vc_status "$path")\"
		echo -e pwd-ps1[$path]=\"$(__pwd_ps1 "$path")\"
		echo -e vc-ps1[$path]=\"$(__vc_ps1 "$path")\"
	done
}

vc_ps1()
{
	__vc_ps1 $@
}

vc_screen()
{
	__vc_screen $@
}

vc_gitflags()
{
  __vc_git_flags "$@"
}


# special updater (for Bash PROMPT_COMMAND)
vc_prompt_command()
{
	d="$1"
	[ -z "$d" ] && d="$(pwd)"
	[ ! -d "$d" ] && error "No such directory $d" 3

	# cache response in file
	statsdir=$(statusdir.sh assert vc_status)
	#index=$(statusdir.sh _index vc_status)
	pwdref=$(echo $d|md5sum -|cut -f1 -d' ')
	#line=$(cat $index | grep $pwdref)
	if [ ! -e "$statsdir/$pwdref" -o "$d/.git" -nt "$statsdir/$pwdref" ]
	then
		#echo -e "$pwdref\t$d" > $index
		__vc_status $d > "$statsdir/$pwdref"
	fi

	cat "$statsdir/$pwdref"
}


vc_list_submodules()
{
  git submodule foreach | sed "s/.*'\(.*\)'.*/\1/"
}

vc_man_1_gh="Clone from Github to subdir, adding as submodule if already in checkout. "
vc_spc_gh="gh <repo> [<prefix>]"
vc_gh() {
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

vc_largest_objects()
{
  test -n "$1" || set -- 10
  $PREFIX/bin/git-largest-objects.sh $1
}

# list commits for object sha1
vc_path_for_object()
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
vc_list_objects()
{
  git verify-pack -v .git/objects/pack/pack-*.idx
}

vc_object_contents()
{
  git cat-file -p $1
}

vc_man_1_excludes="List path ignore patterns"
vc_excludes()
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
vc_ufx()
{
  vc_excluded
}
vc_excluded()
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
    ( cd $path && vc_excluded )
  done
}

# List all unversioned excluding ignored
vc_uf()
{
  vc_unversioned_files
}
vc_unversioned_files()
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
    ( cd $path && vc_unversioned_files )
  done
}

# Annex diag.
vc_annex_unused()
{
  git annex unused | grep '\s\s*[0-8]\+\ \ *.*$' | \
  while read line
  do
    echo $line
  done
}

vc_annex_show_unused()
{
  c_annex_unused | while read num key
  do
    echo "GIT log for '$key'"
    git log --stat -S"$key"
  done
}

vc_annex_clear_unused()
{
  test -z "$1" && {
    local cnt
    cnt="$(c_annex_unused | tail -n 1 | cut -f 1 -d ' ')"
    c_annex_unused | while read num key
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

vc_contains()
{
  test -n "$1" || error "expected file path argument" 1
  test -f "$1" || error "not a file path argument '$1'" 1
  test -n "$2" || set -- "$1" "."
  test -z "$3" || error ""

  sha1="$(git hash-object "$1")"
  info "SHA1: $sha1"

  { ( cd "$2" ; git rev-list --objects --all | grep "$sha1" ); } && {
    note "Found regular GIT object"
  } || c_annex_contains "$1" "$2" || {
    warn "Unable to find path in GIT at @$2: '$1'"
  }
}

vc_annex_contains()
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
vc_list_prefixes()
{
  git submodule foreach | sed "s/.*'\(.*\)'.*/\1/"
}

# List all nested repositories, excluding submodules
# XXX this does not work properly, best use it from root of repo
# XXX: takes subdir, and should in case of being in a subdir act the same
vc_list_subrepos()
{
  basedir="$(dirname "$(__vc_gitdir "$1")")"
  test -n "$1" || set -- "."

  pushd $basedir >>/dev/null
  vc_list_prefixes > /tmp/vc-list-prefixes
  popd >>/dev/null

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

vc_status()
{
  printf "" > /tmp/vc-status
  for gitdir in */.git
  do
    dir="$(dirname "$gitdir")"
    pushd "$dir" >>/dev/null
    git diff --quiet && {
      info "$dir OK"
    } || {
      echo "$dir" >> /tmp/vc-status
    }
    popd >>/dev/null
  done
  cat /tmp/vc-status | while read path
  do
    warn "Modified: $path"
  done
}

vc_projects()
{
  test -f projects.sh || touch projects.sh

  pwd=$(pwd -P)

  for gitdir in */.git
  do
    dir="$(dirname "$gitdir")"
    pushd "$dir" >>/dev/null
    git remote | while read remote
    do
      url=$(git config remote.$remote.url)
      grep -q ${dir}_${remote} $pwd/projects.sh || {
        echo "${dir}_${remote}=$url" >> $pwd/projects.sh
      }
    done
    popd >>/dev/null
  done
}

vc_remotes()
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

# ----


### Main

vc__main()
{
  # Do something if script invoked as 'vc.sh'
  local scriptname=vc base=$(basename $vc_source .sh) \
    subcmd=$1

  case "$base" in $scriptname )

        local func=$(echo vc_$subcmd | tr '-' '_')

        type $func >/dev/null 2>&1 && {
          shift 1
          vc_load
          $func "$@"
        } || {
          vc_load
          vc_print_all "$@"
        }

      ;;

    * )
      echo "Not a frontend for $base ($scriptname)"
      exit 1
      ;;

  esac
}


# Ignore login console interpreter
case "$0" in "" ) ;; "-*" ) ;; * )

  # Ignore 'load-ext' sub-command

  # XXX arguments to source are working on Darwin 10.8.5, not Linux?
  # fix using another mechanism:
  test -z "$__load_lib" || set -- "load-ext"

  case "$1" in load-ext ) ;; * )

      vc__main "$@"
      ;;

  esac ;;

esac

