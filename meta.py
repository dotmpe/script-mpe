#!/usr/bin/env python
"""
:created: 2013-12-30
:updated: 2015-02-27

Look for metafiles, dump paths with missing sources.
"""
import os
import sys

from script_mpe.res import Volumedir, File, Dir
from script_mpe.res.metafile import MetafileFile, Meta, Metadir, Metafile



vdir = list(Volumedir.find())
if not vdir:
    print "No volume here"
    sys.exit(1)

meta = Meta(vdir)
print meta

if sys.argv[1:]:

    for path in sys.argv[1:]:

        mff = MetafileFile(path)
        try:
            mff = MetafileFile(path)
        except Exception, e:
            print >>sys.stderr, path, e
            continue

        if not os.path.exists(mff.path):
            print 'Missing', mff.path, mff.data.keys()

else:

    #meta.dir.walk()
    #for fn in Dir.walk('.'):
    #    print Metafile(fn)
    mf = Metafile(File('meta.py'))
    print mf
    print mf.atime

