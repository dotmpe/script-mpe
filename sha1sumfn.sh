#!/bin/bash

# clean script for media dir


rename_incomplete() # $1: path  2: partialsuffix  3:  fileext
{
	F=$(echo $1 | sed s/$2//g)
	if [ "$1" != "$F" ]
	then
		extlen=$(( ${#2} + ${#3} + 1 ))
		if [ "${1:(-$extlen)}" != "$2.$3" ]
		then
			mv -v "$1" "${1:0:(-$extlen)}$2.$3"
		fi
	fi
}

function fix_incomplete()
{
	find ./ -type f -iname "*.incomplete" | while read f
	do
		ext=$(mimereg -qE "$f")
		[ -z "$ext" -o "$ext" = "bin" ] && continue
		rename_incomplete $f .incomplete $ext
	done
}

function add_check()
{
	EXTS="flv"

	for ext in $EXTS
	do
		extlen=$(( ${#ext} + 1 ))
		pattern="*.$ext"
		find ./ -type f -iname "$pattern" | while read f
		do
			base1=$(basename $f .$ext)
			base=$(basename $base1 .incomplete)
			[ "$base" != "$base1" ] && {
				echo "Incomplete $base"; continue;
			}
			check=$(echo $base | sed -rn 's/.*([a-f0-9]{40})/\1/p')

			[ -n "$check" ] && {

				found=$(find ./ -iname '*'$check'.*')
				[ "$f" = "$found" ] && continue;

				echo "Multi?" $found
				continue;
			} || {
				check=$(sha1sum $f|cut -f1 -d' ')
				mv -v "$f" "${f:0:(-$extlen)}.${check}.${ext}"
			}
		done
	done
}

function do_check()
{
	EXTS="flv"

	for ext in $EXTS
	do
		extlen=$(( ${#ext} + 1 ))
		pattern="*.$ext"
		find ./ -type f -iname "$pattern" | while read f
		do
			base1=$(basename $f .$ext)
			base=$(basename $base1 .incomplete)
			check=$(echo $base | sed -rn 's/.*([a-f0-9]{40})/\1/p')
			[ -n "$check" ] && {
				expect=$(sha1sum $f|cut -f1 -d' ')
				[ "$expect" = "$check" ] && { printf .; continue; }
				printf 'F'
			} || { printf '?'; }
		done
	done
}


# Main
if [ -n "$0" ] && [ $0 != "-bash" ]; then
	# Do something if script invoked as 'sha1sumfn.sh'
	if [ "$(basename $0)" = "sha1sumfn.sh" ]; then
		# invoke with function name first argument,
		func="$1"
		type $func >/dev/null 2>&1 && {
			shift 1
			$func "$@"
			echo $func "$@" done
		}
	fi
fi

