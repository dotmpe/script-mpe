#!/usr/bin/env python
"""
:created: 2013-12-30
:updated: 2015-02-27

Look for metafiles, dump paths with missing sources.
"""
from __future__ import print_function
import os
import sys

from script_mpe.res import Volumedir, File, Dir, Workspace
from script_mpe.res.metafile import MetafileFile, Meta, Metadir, Metafile



if __name__ == '__main__':
    args = sys.argv[1:]
    if '-h' in args:
        print(__doc__)
        sys.exit(0)

    #ws = Workspace.find(os.curdir)#, prog.pwd, prog.home)
    vdir = None
    #vdir = list(Volumedir.find())
    #if not vdir:
    #    print("No volume here")
    #    sys.exit(1)

    meta = Meta(vdir)

    if args:

        for path in args:

            try:
                mff = MetafileFile(path)
            except Exception as e:
                print(path, e, file=sys.stderr)
                continue

            if not os.path.exists(mff.path):
                print('Missing', mff.path, mff.data.keys())
            else:
                print(path, mff.data.keys())
                print(mff.data['Digest'])
                print(mff.get_sha1sum())

    else:

        #meta.dir.walk()
        #for fn in Dir.walk('.'):
        #    print(Metafile(fn))

        mf = Metafile(File('meta.py'))
        print(mf)
        #print(mf.atime)
