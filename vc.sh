#!/usr/bin/env bash
#
# SCM util functions and pretty prompt printer for Bash, GIT
# TODO: other SCMs, BZR, HG, SVN (but never need them so..)
# XXX: more in projectdir.sh in private repo
#
HELP="vc - version-control helper functions "

source ~/bin/statusdir.sh
statusdir_assert vc_status > /dev/null

set -e

scriptname=vc

load()
{
	noop
}

vc_usage()
{
	echo 'Usage: '
	echo "  $scriptname <cmd> [<args>..]"
}

vc_commands()
{
	c_usage
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

homepath ()
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
# u: '%'
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
					u="%"
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

		if [ -n "${2-}" ]; then
			printf "$2" "$c${b##refs/heads/}$w$i$s$u$r"
		else
			printf " (%s)" "$c${b##refs/heads/}$w$i$s$u$r"
		fi

		popd >> /dev/null
	fi
}

. ~/.conf/bash/git-completion.bash

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
		if [ "$(bzr status|grep unknown)" ]; then s="${s}%"; fi
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

# special updater (for Bash PROMPT_COMMAND)
vc_prompt_command()
{
	d="$1"
	[ -z "$d" ] && d="$(pwd)"
	[ ! -d "$d" ] && error "No such directory $d" 3

	# cache response in file
	statsdir=$(statusdir_assert vc_status)
	#index=$(statusdir_index vc_status)
	pwdref=$(echo $d|md5sum -|cut -f1 -d' ')
	#line=$(cat $index | grep $pwdref)
	if [ ! -e "$statsdir/$pwdref" -o "$d/.git" -nt "$statsdir/$pwdref" ]
	then
		#echo -e "$pwdref\t$d" > $index
		__vc_status $d > "$statsdir/$pwdref"
	fi

	cat "$statsdir/$pwdref"
}


. ~/bin/std.sh


# Main
if [ -n "$0" ] && [ $0 != "-bash" ]; then
	# Do something if script invoked as 'vc.sh'
	if [ "$(basename "$0")" = "vc.sh" ]; then
		# invoke with function name first argument,
		func=$1
		type "vc_$func" &>/dev/null && { func="vc_$func"; }
		cmd=$func
		type $func &>/dev/null && {
			shift 1
			load
			$func $@
		} || { 
			load
			vc_print_all $@
		}
	fi
fi

