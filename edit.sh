#!/bin/bash
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
        && echo Publishing... && ( git push origin test || exit 2 ) \
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
    #git diff HEAD --no-ext-diff -- $1
}
function commit()
{
    echo git add $1
    echo git commit
    echo git push origin test
}
update
dirty=$?
while [ $dirty -ne 0 ];
do 
    echo Dirty... $dirty
    update
    dirty=$?
done
echo OK
#update $1
while [ 1 ]
do
    $EDITOR $1
    update
    echo You where editing $1
    read -n 1 -p "Continue? [Y/n] " C
    ( [ "$C" = "n" ] || [ "$C" = "N" ] ) && exit 0
done

#update $1
#commit $1

