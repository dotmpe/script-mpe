#!/usr/bin/env python
"""
FIXME: sync taxus to (or from?) local indices,
    and/or maintain simple local indices without taxus.
"""
from __future__ import print_function
import hashlib
import os
import shelve
import sys

import res
import confparse
from res import Volumedir
from res.fs import Dir
from first20 import normalize


def key( obj ):
    return hashlib.sha1( obj ).hexdigest()

#class PathStore:
#    def __init__(self, voldir ):
#        self.voldir = voldir
#        self.shelve = shelve.open( os.path.join( voldir, 'fscard.db' ) )


if __name__ == '__main__':
    argv = list( sys.argv )
    script_name = argv.pop(0)
    if '-h' in argv:
        print(__doc__)
        sys.exit()

    size_threshold = 14 * 1024 ** 6

    if argv: path = argv.pop()
    else: path = os.getcwd()

    fscard_dbref = list(confparse.find_config_path( 'fscard', path=path, suffixes=['.db']))
    if not fscard_dbref:
        print("No fscard file")
        sys.exit(1)
    shelve = shelve.open( fscard_dbref[0], 'r' )

    for k in shelve:
        print(k, shelve.get(k))
    sys.exit(0)

    sitefiles = list(
            confparse.find_config_path('Sitefile', suffixes=[
                '.json', '.yaml', '.py', '.js'
            ]))
    if sitefiles:
        settings = confparse.load_path( sitefiles[0], confparse.YAMLValues ).sitefile
    else:
        homesitefile = os.path.expanduser('~/Sitefile.yaml')
        settings = confparse.load_path( homesitefile, confparse.YAMLValues ).sitefile

    res.File.ignore_paths = settings.res.File.ignore_paths
    res.File.ignore_names = settings.res.File.ignore_names
    res.Dir.ignore_paths = settings.res.Dir.ignore_paths
    res.Dir.ignore_names = settings.res.Dir.ignore_names


    walk_opts = confparse.Values(dict(
        interactive=False,
        recurse=True,
        max_depth=-1,
        include_root=False,
        # custom filters:
        exists=None, # 1 , -1 for exclusive exists; or 0 for either
        # None for include, False for exclude, True for exclusive:
        dirs=None,
        files=None,
        symlinks=None,
        links=None,
        pipes=None,
        blockdevs=None,
    ))

    cnt = 0
    for f in Dir.walk( path, walk_opts ):
        if os.path.isdir( f ):
            continue
        if os.path.getsize( f ) > size_threshold:
            p = normalize( f )
            k = key( p )

            #if k not in shelve:
            #    shelve[ k ] = p
            #else:
            #    assert k in shelve

            cnt += 1
    print(cnt)
