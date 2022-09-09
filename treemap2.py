#!/usr/bin/env python
"""
TODO: treemap in SQL / relational DB.

Relational model:

------ ------------- ------------ ----------------
path   parent-ref    file-count   disk-usage
------ ------------- ------------ ----------------

Additionally beside a short unique ID,
the implementation may require indicies to quickly query for all leafs,
or all roots if possible.


Flat DB model:

'fc:'path  => file-count
'du:'path  => disk-usage

"""
from __future__ import print_function
import os
import anydbm

from script_mpe.fsutil import hr, humanreadable


def free_space(path):
    if os.path.exists(path):
        s = os.statvfs(path)
        return s.f_bsize * s.f_bavail
    return 0

def _getsize(path):
    if os.path.exists(path) and os.path.isfile(path):
        return os.path.getsize(path)
    return 0

FC_KEY = "fc:%s"
DU_KEY = "du:%s"
CDU_KEY = "cdu:%s"

def init(path):
    global db
    print('Initializing for', path)
    for root, dirs, files in os.walk(path):
        if not os.path.exists(root):
            print('Skipping', root)
            continue
        root = os.path.realpath(root)
        db[ FC_KEY % root ] = str(len(files))
        disk_usage = str(sum(map(lambda f:_getsize(os.path.join(root,f)), files)))
        db[ DU_KEY % root ] = disk_usage

    for root, dirs, files in os.walk(path, False):
        root = os.path.realpath(root)
        if not os.path.exists(root):
            continue
        disk_usage = int(db[ DU_KEY % root ]);
        if CDU_KEY % root in db:
            disk_usage += int(db[CDU_KEY % root])
        key = CDU_KEY % os.path.dirname(root)
        if key not in db:
            db[key] = str(0)
        cummulative = int(db[key]) + disk_usage
        #print key, cummulative, '=', db[key], '+', disk_usage, root
        db[key] = str(cummulative)

def echo(path):
    global db
    path = os.path.realpath(path)
    print('Path:', path)
    if FC_KEY % path in db:
        if CDU_KEY % path in db:
            v = int(db[CDU_KEY % path])
            print("Cummulative:", humanreadable(v))
        v = int(db[DU_KEY % path])
        print("Local:", humanreadable(v))
        print("Local Files:", db[FC_KEY % path])
    #print 'Free space:', humanreadable(free_space(path))


if __name__ == '__main__':
    import sys
    args = sys.argv[1:]
    if '-h' in args:
        print(__doc__)
        sys.exit(0)

    db = anydbm.open(os.path.expanduser('~/.x-pytreemap.db'), 'c')

    path = '.'
    if args:
        path = args[-1]
        if args[0] == 'init':
            if path == args[0]:
                path = '.'
            init(path)
            sys.exit()

    echo(path)

    db.close()
