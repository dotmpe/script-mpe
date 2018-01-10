#!/usr/bin/env python
"""msglink - symlink email to cwd

Search ~/mail dir for a pattern,
foreach result as filed email message,
find date and subject line in file,
symlink to message from current dir,
using date and subject line for name.
"""
from __future__ import print_function
import sys
import os
import re


path = '~/mail/'

grep = sys.argv[1]
if len(sys.argv)>2:
    path += sys.argv[2]

stdout = os.popen('grep -rl "%s" %s' % (grep, path)) # recursive and filenames only

lines = stdout.readlines()

if len(lines) == 0:
    sys.exit("no results for '%s'" % grep)

for line in lines:

    path = line.strip()

    msg = open(path, 'U').read()
    fn = ''
    subjmatch = re.search("^Subject\:\ (.*)$", msg, re.MULTILINE)
    datelmatch = re.search("^Date\:\ (.*)$", msg, re.MULTILINE)
    if not datelmatch:
        print("Could not find date line in %s for '%s'" % (path, grep))
    else:
        fn += datelmatch.group(1) + ' -'
    if not subjmatch:
        print("Could not find subject line in %s for '%s'" % (path, grep))
    else:
        fn += ' ' + subjmatch.group(1)

    nr = 0
    while os.path.exists(fn):
        fn = subjmatch.group(1) + '.%u' % nr
        nr += 1
    print(" * ('%s', <%s>) msglink> <./%s>" % (grep, path, fn))
    os.symlink(path, './%s' % fn)
