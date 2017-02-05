import os
import shelve
import sys

from res import Volumedir
from res.fs import Dir


def normalize( rootdir, path ):
    if os.path.isdir( path ):
        if not path.endswith( os.sep ):
            path += os.sep
    assert isdir( rootdir )
    if not rootdir.endswith( os.sep ):
        rootdir += os.sep
    assert path.startswith( rootdir )
    path = path[ len( rootdir ): ]
    return path


class Store:
    def __init__(self, voldir ):
        self.voldir = voldir
        self.shelve = shelve.open( join( voldir, 'first20.db' ) )


if __name__ == '__main__':

    argv = list( sys.argv )
    script_name = argv.pop(0)
    size_threshold = 14 * 1024 ** 6

    path = argv.pop()
    voldir = Volumedir.find(path)
    store = Store( voldir )

    w_opts = Dir.walk_opts
    w_opts.recurse = True
    for f in Dir.walk( path, w_opts ):
        if os.path.isdir( f ):
            continue
        if os.path.getsize( f ) > size_threshold:
            first20 = open( f ).read( 20 )
            p = normalize( f )
            if first20 not in store.shelve:
                store.shelve[ first20 ] = [ p ]
            else:
                assert p in store.shelve[ first20 ]



