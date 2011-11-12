#!/bin/bash
#
# This will start an editing session for file $1
# 
# The session is started by synchronizing using GIT and one origin remote
# repository. Then $EDITOR is started for the file. 
# Upon closing, the environment is resynchronized. 
#
origin=$(git remote -v|grep origin|grep fetch|sed -e 's/^origin.\(.*\)..fetch./\1/g')
echo 'Origin:' $origin
[ "$origin" ] || ( echo Need to work from GIT checkout. && exit 2 )
[ "$EDITOR" ] || ( echo Editor environment not set. && exit 3 )

function update()
{
    echo Updating...
    echo test @ origin
    [ "$(git status|grep '\(new.file\|added\|modified\|deleted\):')" ] && (
        echo "Consolidating..." \
        && git add --interactive \
        && git commit \
        && return 1
    ) || (
        echo "Synchronizing..." \
        && ( [ "$(git status|grep 'On branch test')" ] || (
            echo "Switching to environment branch..." && git checkout test
        ) ) \
        && echo Rebasing.. && ( git pull --rebase origin test || exit 1 ) \
        && echo Publishing... && ( \
            git push origin test || exit 2 \
        ) \
        && return 0 
    ) 
}
function edit()
{
    ( 
        [ ! -f "$1" ] \
        && touch $1 \
        && ( \
            [ "$(git status $1 | grep Untracked)" ] \
            && echo Adding new file: $1 \
            && git add $1
        ) || ( \
            echo "Error creating $1"
        )
    ) || (
        [ "$(git status $1 | grep -i modified)" ] \
        && echo Modified file: $1
    ) || (
        echo git status $1
    )
}
function sync()
{
    update
    dirty=$?
    while [ $dirty -ne 0 ];
    do 
        echo Dirty... $dirty
        update
        dirty=$?
    done
    echo OK
}
# Main
sync
while [ 1 ]
do
    $EDITOR $1
    sync
    echo You where editing $1
    read -n 1 -p "Continue? [Y/n] " C
    ( [ "$C" = "n" ] || [ "$C" = "N" ] ) && exit 0
done

# TODO: use externals
#d=.
#[ -f "$1" ] && d=$(dirname $1)
#update.sh $d

