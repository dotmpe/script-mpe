#!/bin/bash
# source: 
#   http://ubuntuforums.org/showthread.php?t=726466

TAGNAME="Favorites"
DBFILE="$HOME/.gnome2/f-spot/photos.db"

function createDirectory {
    if [ ! -d $1 ]; then
        echo "Creating directory $1";
        mkdir $1;
    fi
}

function createSymlink {
    if [ ! -e $2 ]; then
        echo "Creating symlink $2";
        ln -s $1 $2
    fi
}

function checkDB {
    if [ ! -e $DBFILE ]; then
        echo "f-spot database file not found $DBFILE"
        exit;
    fi
}

checkDB;

sqlite3 $DBFILE <<SQL_ENTRY_TAG_1
SELECT p.uri, p.time
FROM
	tags t,
    photo_tags tp,
    photos p
WHERE
    t.name='$TAGNAME' AND
    tp.tag_id=t.id AND
    tp.photo_id=p.id
ORDER BY p.time DESC; 
SQL_ENTRY_TAG_1
exit

createDirectory $path/$TAGNAME;
for line in `sqlite3 $DBFILE <<SQL_ENTRY_TAG_1
SELECT p.uri, t.name
FROM
    tags t,
    photo_tags tp,
    photos p
WHERE
    t.name='$TAGNAME' AND
    tp.tag_id=t.id AND
    tp.photo_id=p.id
ORDER BY p.time; 
SQL_ENTRY_TAG_1`; do
    path=${line%|*}
    name=${line#*|}
    createSymlink $path/$name $path/$TAGNAME/$name
done
