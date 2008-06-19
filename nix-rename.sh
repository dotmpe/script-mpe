pass=""
if test "$#" -eq 0; then
	pass=-1;
else
	pass=$1;
fi;

if test "$pass" -lt 1; then
	for f in *; do rename "s/([^0-9-])([0-9]+)([^0-9-])/\$1.\$2.\$3/g" "$f"; done;
	echo "pass 0 done"
fi;
if test "$pass" -lt 2; then
	for f in *; do rename "s/(^[(\[])|\?|!|([)\]]$)//g" "$f"; done;
	for f in *; do rename "s/[()]/./g" "$f"; done;
	echo "pass 1 done"
fi;
if test "$pass" -lt 3; then
	for f in *; do rename "s/[\[\]]/./g" "$f"; done;
	echo "pass 2 done"
fi;
if test "$pass" -lt 4; then
	for f in *; do rename "s/(\ -\ )|(\ \&\ )|(:\ )/./g" "$f"; done;
	echo "pass 3 done"
fi;
if test "$pass" -lt 5; then
	for f in *; do rename "s/[,\ \_-]+/-/g" "$f"; done;
	echo "pass 4 done"
fi;
if test "$pass" -lt 6; then
	for f in *; do rename "s/-\.+|\.+/./g" "$f"; done;
	echo "pass 5 done"
fi;
if test "$pass" -lt 7; then
	for f in *; do rename "s/\.-+|-+/-/g" "$f"; done;
	echo "pass 6 done"
fi;
#if test "$pass" -lt 7; then
#	for f in *; do rename "s/[\.]+/./g" "$f"; done;
#	echo "pass 6 done"
#fi;
