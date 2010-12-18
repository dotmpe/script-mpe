#!/bin/sh

#:after: http://blog.tplus1.com/index.php/2007/08/29/how-to-use-vimdiff-as-the-subversion-diff-tool/
#:after: http://dinomite.net/2008/subversion-diff-with-vimdiff/

DIFF="/usr/bin/vimdiff"
# use the 6th and 7th parameter
shift 5
#LEFT=${6}
#RIGHT=${7}
#$DIFF $LEFT $RIGHT
vimdiff "$@"

# Return an errorcode of 0 if no differences were detected, 1 if some were.
# Any other errorcode will be treated as fatal.

# Set $HOME/.subversion/config diff-cmd to point this script (always use this)
# or use an alias for: svn diff --diff-cmd .../svn-vimdiff.sh
