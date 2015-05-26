#!/usr/bin/env python
"""
:created: 2013-12-30
:updated: 2015-02-27

Look for metafiles, dump paths with missing sources.
"""
import os
import sys

from script_mpe.res import Volumedir
from script_mpe.res.metafile import MetafileFile, Meta



vdir = Volumedir.find()
if not vdir:
    print "No volume here"
    sys.exit(1)


#meta = Meta(vdir)
for path in sys.argv[1:]:

    try:
        mff = MetafileFile(path)
    except Exception, e:
        print >>sys.stderr, path, e
        continue

    if not os.path.exists(mff.path):
        print 'Missing', mff.path, mff.data.keys()

