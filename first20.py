import os
from os.path import join, getsize, isdir
import shelve
import sys

from res.fs import Dir
from treemap import find_volume


def normalize( rootdir, path ):
	if isdir( path.encode(' utf-8' ) ):
		if not path.endswith( os.sep ):
			path += os.sep
	assert isdir( rootdir.encode(' utf-8' ) )
	if not rootdir.endswith( os.sep ):
		rootdir += os.sep
	assert path.startswith( rootdir )
	path = path[ len( rootdir ): ]
	return path


class First20Store:
	def __init__(self, voldir ):
		self.voldir = voldir
		self.shelve = shelve.open( join( voldir, 'first20.db' ) )


if __name__ == '__main__':

	argv = list( sys.argv )
	script_name = argv.pop(0)
	size_threshold = 14 * ( 1024 ** 2 )

	path = argv.pop()
	voldir = find_volume( path )
	store = First20Store( voldir )

