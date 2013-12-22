import os
import shelve
import sys

from res.fs import Dir
from treemap import find_volume
from first20 import normalize
from fscard import PathStore


class SHA1Store:
    def __init__(self, voldir ):
        self.voldir = voldir
        self.shelve = shelve.open( join( voldir, 'sha1.db' ) )

if __name__ == '__main__':

    argv = list( sys.argv )
    script_name = argv.pop(0)
    size_threshold = 14 * 1024 ** 6

    path = argv.pop()
    voldir = find_volume( path )
    store = SHA1Store( voldir )

