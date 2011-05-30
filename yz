#!/bin/bash
# Usage:
#
#   yz KEY-1 "1h 15m" "Comment Text"
#
# Changelog
# ~~~~~~~~~~
# 2011-05-21
#   First version.

JIRA=/src/atlassian-jira-cli/jira-cli-2.0.0/jira.sh

if test ! -e .jira
then
    echo "No account file found"
    exit
fi

HOST=

if test -n "$HOST" -a -e .account.$HOST.sh
then
    . .account.$HOST.sh
else
    . .jira
fi

SERVER=http://jira.$HOST/

#TOKEN=`$JIRA -a login --user $USER -p $PASSWORD -s $SERVER`
#echo "Logged in as $USER at $HOST"

COMMENT=$3
TIME=$2
ISSUE=$1

#echo "Logging work by $USER for $ISSUE.."
$JIRA \
	-a addWork \
	--issue $ISSUE \
	--timeSpent $TIME \
	--comment "$COMMENT" \
	-s $SERVER \
	-p $PASSWORD \
	-u $USER 
#	--login $TOKEN



