#!/bin/bash 


# two paths, must not contain links
function in_dir ()
{
	d="$1"
	p="$2"
	[ -e "$d" ] && [ ! -d "$d" ] && d=$(dirname "$d")
	[ -e "$p" ] && [ ! -d "$p" ] && p=$(dirname "$p")
	D="$(cd "$d";pwd)"
	P="$(cd "$p";pwd)"
	DL="${#D}"
	if [ "$D" = "${P:0:$DL}" ]
	then
		return 0
	else
		return 4
	fi
}


find . -type f | while read f 
do
	media_dir=
	if in_dir media "$f"
	then
		media_dir=media
	fi
	for media_dir_ in */media
	do
		if in_dir $media_dir_ "$f"
		then
			media_dir=$media_dir_
		fi
	done
	[ "$media_dir" = "media" ] || movelink $f media
	[ -n "$media_dir" ] && continue
	echo ERROR: is not in media dir: $f
done
