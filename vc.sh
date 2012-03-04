#!/usr/bin/env bash

HELP="vc - version-control helper functions "

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
    cd $1;
    bzr info 2> /dev/null | grep 'branch root' | sed 's/^\ *branch\ root:\ //'
}

# __vc_gitdir accepts 0 or 1 arguments (i.e., location)
# returns location of .git repo
__vc_gitdir ()
{
	if [ -z "${1-}" ]; then
		if [ -n "${__vc_git_dir-}" ]; then
			echo "$__vc_git_dir"
		elif [ -d .git ]; then
			echo .git
		else
			git rev-parse --git-dir 2>/dev/null
		fi
	elif [ -d "$1/.git" ]; then
		echo "$1/.git"
	else
		echo "$1"
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
    cd $1
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
    cd $1
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

__vc_status ()
{
	local w short repo sub
	w=$1;
	short=${w/#"$HOME"/"~"}
	local git=$(__vc_gitdir)
	local bzr=$(__vc_bzrdir)
	if [ "$git" ]; then
		rev=$(git show . |grep '^commit'|sed 's/^commit //' | sed 's/^\([a-f0-9]\{9\}\).*$/\1.../')
		short=${short%$sub}
		echo $short $(__vc_git_ps1 "[git:%s $rev]") $sub
	else if [ "$bzr" ]; then
		#if [ "$bzr" = "." ];then bzr="./"; fi
		sub=${w##$(realpath $bzr)}
		/dev/null short=${short%$sub}
		local revno=$(bzr revno)
		local s=''
		if [ "$(bzr status|grep added)" ]; then s="${s}+"; fi
		if [ "$(bzr status|grep modified)" ]; then s="${s}*"; fi
		if [ "$(bzr status|grep removed)" ]; then s="${s}-"; fi
		if [ "$(bzr status|grep unknown)" ]; then s="${s}%"; fi
		if [ -n "$s" ]; then s=" ${s}"; fi;
		echo "$short [bzr:$s $revno]$sub"
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

# --porcelain not available with old git version @iris
## Exit with 1 if dirty
#git_evil_dirty ()
#{
#    [[ $(git diff --shortstat 2> /dev/null | tail -n1) != "" ]] && exit 1
#}
## Return '*' if branch is dirty
#__git_evil_dirty ()
#{
#    expr `git status --porcelain 2> /dev/null | grep "^??" | wc -l`
#}
#
## Return untracked files
#__git_evil_num_untracked ()
#{
#    expr `git status --porcelain 2> /dev/null | grep "^??" | wc -l`
#}

__git_evil_status ()
{
    git status > /tmp/.git-status
    l=0
    s=0
    e=0
    case $1 in 
        staged)
            # Changes to be committed:
            while read line;
            do
                if [ $s -eq 0 ] 
                then
                    if $(echo "$line"|grep -q '^#\ Changes.to.be.committed.')
                    then
                        s=$(( 3 + $l ))
                    fi
                else
                    if $(echo "$line"|grep -q '^#\ [A-Z].*$' -) || \
                        $(echo "$line"|grep -q '^no.*$' -)
                    then
                        e=$l
                        break;
                    fi
                fi
                l=$(($l + 1))
            done < /tmp/.git-status
            ;;
        changed)
            # Changed but not updated:
            while read line;
            do
                if [ $s -eq 0 ] 
                then
                    if $(echo "$line"|grep -q '^#\ Changed.but.not.updated.')
                    then
                        s=$(( 3 + $l ))
                    fi
                else
                    if $(echo "$line"|grep -q '^#\ [A-Z].*$' -) || \
                        $(echo "$line"|grep -q '^no.*$' -)
                    then
                        e=$l
                        break;
                    fi
                fi
                l=$(($l + 1))
            done < /tmp/.git-status
            ;;
        untracked)
            # Untracked files:
            while read line;
            do
                if [ $s -eq 0 ] 
                then
                    if $(echo "$line"|grep -q '^#\ Untracked.files.')
                    then
                        s=$(( 3 + $l ))
                    fi
                else
                    if $(echo "$line"|grep -q '^#\ [A-Z].*$' -) || \
                        $(echo "$line"|grep -q '^no.*$' -)
                    then
                        e=$l
                        break;
                    fi
                fi
                l=$(($l + 1))
            done < /tmp/.git-status
            ;;
    esac
    [ $s -ne 0 ] && [ $e -eq 0 ] && e=$l
    head -n $(( $e )) /tmp/.git-status | tail -n +$s | grep -v '^#\s*$'
}

__git_staged ()
{
    git st | grep 'modified:' | wc -l
}

__git_changed ()
{
    git st | wc -l 
}

__git_untracked ()
{
    git st | wc -l
}

# Main
#if [ "$(basename $0)" = "vc.sh" ]; then
#    echo -e $(__vc_status .)
#if [ -n "$0" ] && [ $0 != "-bash" ]; then
#    if [ "$(basename $0)" = "vc.sh" ]; then
#        [ -n "$1" ] && [ ! -d "$1" ] && echo "No such directory $1" && exit 3
#        echo -e vc-status[$1]=$(__vc_status $1)
#    fi
#fi
