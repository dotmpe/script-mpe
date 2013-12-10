#!/usr/bin/env bash

[ -n "$VERBOSE" ] || VERBOSE=0

log() # 1:message 2:level 
{
	echo $1
return
	level=$2
	[ -z "$level" ] && level=0;
	[ $level -le $VERBOSE ] && echo "$1"
}

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
	    && target=./$2/$1
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
	if stat -q "$1" > /dev/null
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

### Main

main()
{
	# Get filename from first arg, which is suppoed to be a dir
	if test -n "$1"; then
		F=$1
		if test $F -eq "-"; then
		else
			if test ! -f $F; then
				if test -d $F -a -f $F/.symlinks
				then
					F=$F/.symlinks
				else
					log "! Missing symlinks file: $F" 0;
					exit 2;
				fi
			fi
		fi
	else
		log "Usage: $0 [../dir|file]" 0
		exit 1
	fi

	SRCDIR=$(dirname $F)
	if test -z "$SRCDIR"; then SRCDIR=.; fi

	# Read all lines, two-pass
	# Whitespace determines 'do_symlink' arguments, paths cannot contain any spaces!
	# Lines with wildcard '*' are expanded first (by echo)

	# Expand wildcards, write to temporary file
	expand_symlinks $SRCDIR $F 

	total=$(echo $(wc -l < $F.expanded))
	# Create links and finish
	i=0
	while read line
	do
		[ -e "./$SRCDIR/$line" ] || {
			echo "File does not exist: $SRCDIR/$line. Does it contain spaces?"
			continue
		};

		do_symlink $line $SRCDIR
		R=$?
		[ "$R" == 1 ] && i=$(( $i + 1 )) || continue;
	done < $F.expanded
	rm $F.expanded

	log "OK, symlinked $i out of $total paths. " 0
	exit 0
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

# Run only if scriptname matches (allow other script to include this one)
[ "$(basename $0)" = "init-symlinks-relative.sh" ] && main $*

