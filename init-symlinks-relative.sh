#!/usr/bin/env bash

[ -n "$VERBOSE" ] || VERBOSE=0

. ~/bin/std.sh

[ -z "$FORCE_DELETE" ] && FORCE_DELETE=0

#
# Initialize symlinks from .symlinks
#

do_symlink() # $path $srcdir
{
	[ ! -e "$2/$1" ] \
		&& log "! Symlink path $2/$1 doesn't exist" 0 \
		&& return 5;
	dir=$(dirname $1);
	# reverse path by replace all names with '..'
	[ "$dir" != "." ] \
	    && target=$(echo $dir | sed 's/[^/]*/../g')/$2/$1;
	[ "$dir" == "." ] \
	    && target=$2/$1
	# link exists, continue
	[ -L "$1" ] && [ "$(readlink $1)" = "$target" ] \
		&& return 4;
	# link exists, check if new path is preferred, or keep current path
	[ -e .symlinks.preferred ] && {
		[ -L "$1" ] && {
			grep $2/$1 .symlinks.preferred && {
				echo "Path $1 already exists, but $2 is preferred. "
			} || { 
				echo "Path $1 exists and $2 is not preferred, continueing. "
				return 3;
			}
		}
	}
	# paths exists, remove if link
	[ -e "$1" ] && [ "$FORCE_DELETE" != 0 ] \
		&& ( rm -rf "$1" && log "Force deleted: $1" 0 ); 
	if stat "$1" > /dev/null 2> /dev/null
	then
		if [ -L "$1" ] && ( rm $1 )
		then
			log "Removed existing link $1" 0
		else
			log "! Path exists: $1" 0 && return 2
		fi
	fi
	# prep dir
	[ ! -d "$dir" ] && mkdir -p "$dir" && log "Folder: $dir created" 0;
	# Create the symlink with a relative path
	FLAGS="-s";
	[ $VERBOSE -gt 1 ] && { FLAGS="$FLAGS -v"; }
	ln $FLAGS $target "$1";
	return 1
}

expand_symlinks() # SRCDIR F
{
	[ -f $2.expanded ] && rm $2.expanded
	touch $2.expanded
	i=0
	while read line
	do
		# count lines (debugging)
		i=$(expr $i + 1);
		# ignore blanks and comments
		[ -z "$(echo $line|sed 's/\s\+//')" -o "${line:0:1}" = "#" ] && continue;
		# debug print
		[ "$VERBOSE" -gt 2 ] && echo 1=$1, 2=$2, line=$line
		# pick up wildcards in lines
		if test -n "$(echo ---$line | grep '\*')"
		then	
			# length of srcpath
			l=$(expr ${#1} + 1)
			if test -n "$(echo ---$line | grep '\*\*')"
			then	
				# expand line using find file
				end=$(expr ${#line} - 3)
				search=$1/${line:0:$end}
				i=0
				for f in $(find $search -type f -or -type l)
				do
					i=$(( $i + 1 ));
					# write subpath to file
					echo ${f:$l} >> $2.expanded
				done
				echo "Expanded '$line' to $i paths. "
			else
				# expand line using bash globbing
				i=0
				for f in $1/$line
				do
					i=$(( $i + 1 ));
					[ -e "$f" ] && \
						echo ${f:$l} >> $2.expanded
				done
				echo "Expanded '$line' to $i paths. "
			fi
		else
			# test 
			if test ! -e "$1/$line"
			then
				echo "! Non-existant path '$line', given at $2:$i"
				continue
			else
				echo $line >> $2.expanded
			fi
		fi
	done < $2 
}


### Main


# Variables:
# source of symlinks
FILE=
# root to evaluate symlinks from
SRCDIR=
# print but no actions
DRYRUN=

run()
{
	# Read all lines, two-pass
	# Whitespace determines 'do_symlink' arguments, paths cannot contain any spaces!
	# Lines with wildcard '*' are expanded first (by echo)

	# Expand wildcards, write to temporary file
	expand_symlinks $SRCDIR $FILE

	total=$(echo $(wc -l < $FILE.expanded))
	# Create links and finish
	i=0
	while read line
	do
		[ -e "$SRCDIR/$line" ] || {
			echo "File does not exist: $SRCDIR/$line. Please check it for spaces or broken symlinks, etc. "
			continue
		}
		do_symlink $line $SRCDIR
		R=$?
		[ "$R" == 1 ] && i=$(( $i + 1 )) || continue;
	done < $FILE.expanded
	#rm $FILE.expanded

	log "OK, symlinked $i out of $total paths. " 0
	exit 0
}

main() 
{
	# First script argument:
	SCRIPT=$0
	# Gobble up other arguments:
	while test -n "$*"
	do
		case $1 in
			"-n")
				DRYRUN=1
				;;
			"-")
				FILE="-"
				SRCDIR=$(dirname $SCRIPT)
				;;
			*)
				if test -e $1
				then
					case $(stat -c %F $1) in
						"regular file")
							FILE=$1
							SRCDIR=$(dirname $FILE)
							;;
						"directory")
							SRCDIR=$1
							if test ! -e "$SRCDIR/.symlinks"
							then
								FILE=/tmp/init-symlinks.tmp
								echo "*" > $FILE
							fi
							;;
						*)
							log "Unhandled path: $1" 0
							exit 2
					esac
				else
					log "Usage: $0 [../dir|file|-]" 0
					exit 1
				fi
				;;
		esac
		shift 1
	done

	# sanity check
	if test -z "$FILE"
	then exit 3
	fi

	echo "Symlinking from $SRCDIR ($FILE)"

	if test "$FILE" != "-"
	then
		exec 6<&0 # Link fd#6 with stdin
		exec < $FILE # Replace stdin with file
	fi
	run
	if test "$FILE" != "-"; then
		exec 0<&6 6<&- # restore stdin and close fd#6
	fi
}

# Run only if scriptname matches (allow other script to include this one)
[ "$(basename $0)" = "init-symlinks-relative.sh" ] && main $*

