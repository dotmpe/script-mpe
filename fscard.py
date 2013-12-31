#!/usr/bin/env python
import hashlib
import os
import shelve
import sys

from res.fs import Dir
from treemap import find_volume
from first20 import normalize


def key( obj ):
    return hashlib.sha1( obj ).hexdigest()

class PathStore:
    def __init__(self, voldir ):
        self.voldir = voldir
        self.shelve = shelve.open( join( voldir, 'fscard.db' ) )

if __name__ == '__main__':

    argv = list( sys.argv )
    script_name = argv.pop(0)
    size_threshold = 14 * 1024 ** 6

    path = argv.pop()
    voldir = find_volume( path )
    store = PathStore( voldir )

    for f in Dir.walk( path, w_opts ):
        if os.path.isdir( f ):
            continue
        if os.path.getsize( f ) > size_threshold:
            p = normalize( f )
            k = key( p )
            if k not in store.shelve:
                store.shelve[ k ] = p
            else:
                assert k in store.shelve

