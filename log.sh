#!/bin/bash

# left align first columnt at:
FIRSTTAB=${FIRSTTAB-24}

if [ -z "$CS" ]
then
	echo "make: warning, using dark colorscheme (set CS to override)" 1>&2
	CS=dark
fi
COLOURIZE=yes

# Shell colors
if [ "$COLOURIZE" == "yes" ]
then
	if [ "$CS" == "light" ]
	then
		# primary, black
		c0="\x1b[0;0;30m"
		# pale (inverted white)
		c7="\x1b[0;7;37m"
		# hard (bright black, ie. dark gray)
		c9="\x1b[0;1;30m"
	else
		# primary, pale white
		c0="\x1b[0;0;0m"
		# pale (normal white, ie. light gray)
		c7="\x1b[0;0;37m"
		# hard (bold white)
		c9="\x1b[1;1;37m"
	fi
	# warning color, red
	c1="\x1b[0;1;31m"
	# ok color, green
	c2="\x1b[0;0;32m"
	c21="\x1b[0;1;32m"
	# running, orange
	c3="\x1b[0;0;33m"
	c31="\x1b[0;1;33m"
	# updated, blue
	c41="\x1b[0;1;34m"
	c4="\x1b[0;0;34m"
fi
## Make output strings
mk_title_blue="$c7$c41%s$c7:$c0"
mk_title_blue_faint="$c7$c4%s$c7:$c0"
mk_p_trgt_blue="$c41[$c7%s$c41]$c0"
#mk_p_trgt_blue_faint="$c4[$c7%s$c4]$c0"
mk_trgt_blue="$c41<$c7%s$c41>$c0"
#mk_trgt_blue_faint="$c4<$c7%s$c4>$c0"
mk_trgt_yellow="$c31<$c7%s$c31>$c0"
#mk_trgt_yellow_faint="$c3<$c7%s$c3>$c0"
mk_p_trgt_yellow="$c31[$c7%s$c31]$c0"
mk_p_trgt_yellow_faint="$c3[$c7%s$c3]$c0"
mk_p_trgt_green="$c21[$c7%s$c21]$c0"
mk_trgt_green="$c21<$c7%s$c21>$c0"
#mk_trgt_green_faint="$c2<$c7%s$c2>$c0"
mk_trgt_red="$c1<$c7%s$c1>$c0"
mk_p_trgt_red="$c1[$c7%s$c1]$c0"
mk_updtd="$c4<$c7%s$c4>$c0"


__log ()
{
	linetype=$(echo $1|tr 'A-Z' 'a-z')
	targets=$(echo "$2")
	trgt_len=${#targets}
	msg=$3
	sources=$(echo "$4")

	if [ -n "$sources" ];
	then
		sources=$(printf "$mk_trgt_blue" "$sources")
		msg="$msg $sources"
	fi
	case "$linetype" in
		header | header1) # blue
			#targets=$(printf "$mk_title_blue" "$targets")
			targets=$(printf "$mk_p_trgt_blue" "$targets")
			;;
		header2 )
			targets=$(printf "$mk_title_blue" "$targets")
			;;
		header3 )
			targets=$(printf "$mk_title_blue_faint" "$targets")
			;;
		debug )
			targets="";
			trgt_len=0
				#$(printf "$mk_p_trgt_yellow_faint" "$targets")
			;;
		verbose | warn*  )
			targets=$(printf "$mk_p_trgt_yellow_faint" "$targets")
			;;
		attention | crit* )
			targets=$(printf "$mk_p_trgt_yellow" "$targets")
			;;
		file[_-]target )
			targets=$(printf "$mk_trgt_yellow" "$targets")
			;;
		file[_-]ok )
			targets=$(printf "$mk_trgt_green" "$targets")
			;;
		file[_-]warn* )
			targets=$(printf "$mk_trgt_yellow" "$targets")
			;;
		file[_-]err* ) # red
			targets=$(printf "$mk_trgt_red" "$targets")
			;;
		err* | fatal | fail* ) # red
			targets=$(printf "$mk_p_trgt_red" "$targets")
			;;
		 ok | "done" | info | *  )
			targets=$(printf "$mk_p_trgt_green" "$targets")
			;;
	esac
	case "$linetype" in
		file[_-]error|file[_-]warn*|file[_-]target|file[_-]ok|header|header1|header2|header3|debug|info|attention|error|verbose)
			;;
		fatal|ok|'done'|* )
			if [ -n "$msg" ]
			then msg="$c9$1$c0, $msg";
			else msg="$c9$1$c0"; fi
			;;
	esac
	if [ -n "$msg" -a -z "$sources" ]
	then
		msg="$msg.";
	fi
	len=$(expr $FIRSTTAB - $trgt_len)
	case "$linetype" in
		debug)
			len=$(expr $len + 2)
			;;
		'header2'|header3)
			len=$(expr $len + 1)
			;;
	esac
	if [ $len -lt 0 ]; then len=0; fi
	padd=" ";
	padding=''
	while [ ${#padding} -lt $len ]; do
		padding="$padd$padding"
	done;
	echo -e " $padding$targets $msg$c0 "
}


# Start in stream mode or print one line and exit.
if test "$1" = '-'
then
	export IFS="	"; # tab-separated fields for $inp
	while read lt t m s;
	do
		__log "$lt" "$t" "$m" "$s";
	done
else
	# quoted arguments:
	__log "$1" "$2" "$3" "$4";
fi
