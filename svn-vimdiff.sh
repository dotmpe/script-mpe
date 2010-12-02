#!/bin/sh

:after: http://blog.tplus1.com/index.php/2007/08/29/how-to-use-vimdiff-as-the-subversion-diff-tool/

DIFF="/usr/bin/vimdiff"

# Subversion provides the paths we need as the sixth and seventh
# parameters.
LEFT=${6}
RIGHT=${7}

# Call the diff command (change the following line to make sense for
# your merge program).
$DIFF $LEFT $RIGHT

# Return an errorcode of 0 if no differences were detected, 1 if some were.
# Any other errorcode will be treated as fatal.

# Set $HOME/.subversion/config file to point this script
