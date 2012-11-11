#!/bin/bash

SRC_F="-iname \"*.py\" -or -iname \"*.sh\" -or -iname \"*.hx\" -or -iname \"*.c\" -or -iname \"*.h\" -or -iname \"*.java\" -or -iname \"*.php\" "
#TPL_F=-iname \"*.tpl\" -or \"*.html\" -or \"*.\"

echo "# Name, Rev, Branch, Src files, Src LOC"

function update() # NAME BRANCH
{
	if [ "${BRANCH:0:3}" = "dev" ]
	then
		echo $BRANCH
	fi
}

p=$(pwd)
find ~/project/ -iname .git | while read f
do
	F=$(dirname $f)
	cd $F
	NAME=$(basename $F)
	REV=$(echo $(git show | grep ^commit| sed 's/commit //'))
	BRANCH=$(echo $(git branch | grep '\*' | sed 's/\* //'))
	SRC_FILES=$(echo $(eval find ./ $SRC_F | wc -l))
	SRC_LOC=$(echo $(eval find ./ $SRC_F -exec cat {} + | wc -l))

	update $NAME $BRANCH
	echo $NAME, $REV, $BRANCH, $SRC_FILES, $SRC_LOC
	cd $p
	#-exec 'cat {} | wc -l ' +
done




