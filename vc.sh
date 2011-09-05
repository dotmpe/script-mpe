#!/usr/bin/env bash

PSEP="\[\033[1;30m\]:\[\033[00m\]"
PAT="\[\033[1;30m\]@\[\033[00m\]"

__vc_bzrdir ()
{
    cd $1;
    bzr info 2> /dev/null | grep 'branch root' | sed 's/^\ *branch\ root:\ //'
}

__vc_pull ()
{
    cd $1
	local git=$(__gitdir)
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
    cd $1
	local git=$(__gitdir)
    local bzr=$(__vc_bzrdir)
	if [ "$git" ]; then
	    git push origin master;
	else if [ "$bzr" ]; then
	    bzr push;
#	else if [ -d ".svn" ]; then
#	    svn 
    fi; fi;
}

__vc_status ()
{
	local w short repo sub
	w=$1;
	short=${w/#"$HOME"/"~"}
	local git=$(__gitdir)
	local bzr=$(__vc_bzrdir)
	if [ "$git" ]; then
		s=$(git show . |grep '^commit'|sed 's/^commit //' | sed 's/^\([a-f0-9]\{9\}\).*$/\1.../')
		short=${short%$sub}
		echo $short$PSEP$(__git_ps1 "[git:%s $s]")$sub
	else if [ "$bzr" ]; then
		#if [ "$bzr" = "." ];then bzr="./"; fi
		sub=${w##$(realpath $bzr)}
		short=${short%$sub}
		local revno=$(bzr revno)
		local s=''
		if [ "$(bzr status|grep added)" ]; then s="${s}+"; fi
		if [ "$(bzr status|grep modified)" ]; then s="${s}*"; fi
		if [ "$(bzr status|grep removed)" ]; then s="${s}-"; fi
		if [ "$(bzr status|grep unknown)" ]; then s="${s}?"; fi
		if [ -n "$s" ]; then s=" ${s}"; fi;
		echo "$short$PSEP[bzr:$revno$s]$sub"
	else if [ -d ".svn" ]; then
		local r=$(svn info | sed -n -e '/^Revision: \([0-9]*\).*$/s//\1/p' )
		local s=""
		if [ "$(svn status | grep -q -v '^?')" ]; then s="${s}*"; fi
		if [ -n "$s" ]; then s=" ${s}"; fi;
		echo "$short$PSEP[svn:r$r$s]"
	else
		echo $short
	fi;fi;fi
}

# <userpath>[<branchname><branchstate>]<branchpath>
# Version Control part for prompt, state indicators:
# + : added files
# * : modified "
# - : removed "
# ? : untracked "
__vc_ps1 ()
{
    __vc_status $1
}

