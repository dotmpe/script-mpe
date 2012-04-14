#!/bin/bash

source vc.sh

cwd=$(pwd -P)
DIR=/tmp/test_vc-git
[ -d $DIR ] && rm -rf $DIR
mkdir $DIR
cd $DIR
git init
echo '*.log' > .gitignore
echo foo > bar; git add bar
git add .
git commit -m "Initial"

echo OK, made new branch
echo -----------------------------------------------------------
echo

git_check ()
{
    #    if git diff --exit-code --quiet HEAD
    #    then
    #        echo > /dev/null
    #    else
    #        echo 'Branch has staged modifications\n'
    #    fi
    echo Staged:
    __git_evil_status staged
    echo Changed:
    __git_evil_status changed
    echo Untracked:
    __git_evil_status untracked
    #if [ $(__git_staged) -gt 0 ]
    #then
    #    echo 'Branch has staged changes\n'
    #fi
    #if [ $(__git_untracked) -gt 0 ]
    #then
    #    echo 'Branch has untracked content\n'
    #fi
    #if [ $(__git_changed) -gt 0 ]
    #then
    #    echo 'Branch has unstaged changes\n'
    #fi
}

#echo -e $(git_check)
echo

echo Modify .gitignore
echo abcde >> .gitignore
if [ $(__git_evil_status staged | wc -l) -ne 0 ]
then
    echo ERROR: Should be 0 staged changes
fi
if [ $(__git_evil_status changed | wc -l) -ne 1 ]
then
    echo ERROR: Should be 1 changed files
fi
if [ $(__git_evil_status untracked | wc -l) -ne 0 ]
then
    echo ERROR: Should be 0 untracked files
fi
echo -----------------------------------------------------------
echo

echo Staging .gitignore
git add .gitignore
#git_check
if [ $(__git_evil_status staged | wc -l) -ne 1 ]
then
    echo ERROR: Should be 1 staged changes
fi
if [ $(__git_evil_status changed | wc -l) -ne 0 ]
then
    echo ERROR: Should be 0 changed files
fi
if [ $(__git_evil_status untracked | wc -l) -ne 0 ]
then
    echo ERROR: Should be 0 untracked files
fi
git commit -m "."
if [ $(__git_evil_status staged | wc -l) -ne 0 ]
then
    echo ERROR: Should be 0 staged changes
fi
echo -----------------------------------------------------------
echo

echo "New file"
touch abcd2
#git_check
if [ $(__git_evil_status staged | wc -l) -ne 0 ]
then
    echo ERROR: Should be 0 staged changes
fi
if [ $(__git_evil_status changed | wc -l) -ne 0 ]
then
    echo ERROR: Should be 0 changed files
fi
if [ $(__git_evil_status untracked | wc -l) -ne 1 ]
then
    echo ERROR: Should be 1 untracked files
fi
rm abcd2
echo -----------------------------------------------------------
echo

echo "Modify file"
echo bar2 >> .gitignore
echo abcd3 >> bar
git add bar
echo abcd4 >> bar
#git_check
if [ $(__git_evil_status staged | wc -l) -ne 1 ]
then
    echo ERROR: Should be 1 staged changes
fi
if [ $(__git_evil_status changed | wc -l) -ne 2 ]
then
    echo ERROR: Should be 2 changed files
fi
if [ $(__git_evil_status untracked | wc -l) -ne 0 ]
then
    echo ERROR: Should be 0 untracked files
fi
echo -----------------------------------------------------------
