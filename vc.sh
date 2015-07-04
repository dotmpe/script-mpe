#!/usr/bin/env bash
#
# SCM util functions and pretty prompt printer for Bash, GIT
# TODO: other SCMs, BZR, HG, SVN
#
HELP="vc - version-control helper functions "

source ~/bin/statusdir.sh
statusdir_assert vc_status > /dev/null



homepath ()
{
	w="$1"
	echo "${w/#$HOME/~}"
}

# Flags legenda:
#
# __vc_git_ps1 : cbwisur
# c: ''|'BARE:'
# b: branchname
# w: '*'
# i: '+'|'#'
# s: '$'
# u: '%'
# 

__vc_bzrdir ()
{
	cd "$1";
	root=$(bzr info 2> /dev/null | grep 'branch root')
	if [ -n "$root" ]; then
		echo $root/.bzr | sed 's/^\ *branch\ root:\ //'
	fi
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
		cd "$D"
		git rev-parse --git-dir 2>/dev/null
	fi
}

# __vc_git_ps1 accepts 0 or 1 arguments (i.e., format string)
# returns text to add to bash PS1 prompt (includes branch name)
__vc_git_ps1 ()
{
	local g="$(__vc_gitdir)"
	if [ -n "$g" ]; then
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
		
		if [ -n "${1-}" ]; then
			printf "$1" "$c${b##refs/heads/}$w$i$s$u$r"
		else
			printf " (%s)" "$c${b##refs/heads/}$w$i$s$u$r"
		fi
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
	cd "$w"
	realcwd="$(pwd -P)"
	short="$(homepath "$w")"
	
	local git="$(__vc_gitdir "$w")"
	local bzr=$(__vc_bzrdir "$w")
	
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
		short="${short%$sub}"
		echo "$short" $(__vc_git_ps1 "[git:%s $rev]")$sub
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
}

# Helper for just path reference notation, no SCM bits
__pwd_ps1 ()
{
	local w short
	
	d="$1";
	[ -z "$d" ] && d="$(pwd)"
	[ ! -d "$d" ] && echo "No such directory $d" && exit 3
	cd "$d"
	w="$d"
	realcwd="$(pwd -P)"
	short=$(homepath $w)
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
	short=$(homepath $w)
	
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
		echo $(basename "$realcwd") $(__vc_git_ps1 "[git:%s $rev]")
	else
		echo "$short"
	fi
}


# print all fuctions/results for paths in arguments
vc_print_all ()
{
	for path in $@
	do
		[ ! -e "$path" ] && continue
		echo -e vc-status[$path]=\"$(__vc_status "$path")\"
		echo -e pwd-ps1[$path]=\"$(__pwd_ps1 "$path")\"
		echo -e vc-ps1[$path]=\"$(__vc_ps1 "$path")\"
	done
}

# special updater (for Bash PROMPT_COMMAND)
vc_prompt_command ()
{
	d="$1"
	[ -z "$d" ] && d="$(pwd)"
	[ ! -d "$d" ] && echo "No such directory $d" && exit 3
	statsdir=$(statusdir_assert vc_status)
	#index=$(statusdir_index vc_status)
	pwdref=$(echo $d|md5sum -|cut -f1 -d' ')
	#line=$(cat $index | grep $pwdref)
	if [ ! -e "$statsdir/$pwdref" -o "$d/.git" -nt "$statsdir/$pwdref" ]
	then
		#echo -e "$pwdref\t$d" > $index
		__vc_status $@ > "$statsdir/$pwdref"
	fi
	cat "$statsdir/$pwdref"
}

# Main
if [ -n "$0" ] && [ $0 != "-bash" ]; then
	# Do something if script invoked as 'vc.sh'
	if [ "$(basename "$0")" = "vc.sh" ]; then
		# invoke with function name first argument,
		func=$1
		type "vc_$func" &>/dev/null && { func="vc_$func"; }
		type $func &>/dev/null && {
			shift 1
			$func $@
		} || { 
			vc_print_all $@
		}
	fi
fi

