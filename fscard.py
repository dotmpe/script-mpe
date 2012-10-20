import hashlib
import os
from os.path import join, isdir, getsize, dirname
import shelve
import sys

from res.fs import Dir
from first20 import normalize, First20Store


def key( obj ):
	return hashlib.sha1( obj ).hexdigest()

class PathStore:
	def __init__(self, voldir ):
		self.voldir = voldir
		self.shelve = shelve.open( join( voldir, 'fscard.db' ) )

def find_dir( dirpath, subleaf ):
	dirparts = dirpath.split( '/' )
	while dirparts:
		path = os.sep.join( dirparts )
		if isdir( os.sep.join( tuple( dirparts )+( subleaf, ) ) ):
			return path
		dirparts.pop()

def strlen( s, l ):
	if len( s ) > l:
		h = round( l / 2 )
		return s[ :h ] + '[...]' + s[ h: ]
	return s

def main( size_threshold, path, voldir, store, first20 ):
	w_opts = Dir.walk_opts
	w_opts.recurse = True
	cnt = 0
	for f in Dir.walk( path, w_opts ):
		if isdir( f.encode( 'utf-8' ) ):
			continue
		cnt += 1
		if getsize( f.encode( 'utf-8' ) ) > size_threshold:

			p = normalize( dirname( voldir ), f )
			k = key( p.encode(' utf-8' ) )
			if k not in store.shelve:
				store.shelve[ k ] = [ p ]
				print k, strlen( store.shelve[ k ], 128 ), 'NEW'
			else:
				assert p in store.shelve[ k ]
				print k, 'OK'

			first20bytes = open( f.encode( 'utf-8' ) ).read( 20 )
			if first20bytes not in first20.shelve:
				first20.shelve[ first20bytes ] = [ p ]
				print k, '20bytes'
			else:
				if p not in first20.shelve[ first20bytes ]:
					print "%s is value for %r, new: %r" % (first20.shelve[
								first20bytes ], first20bytes, p)

		if cnt == 1000:
			sys.stdout.write( "Files: ")
		if not cnt % 1000:
			sys.stdout.write("%s.. "%cnt)
			sys.stdout.flush()

if __name__ == '__main__':

	argv = list( sys.argv )
	script_name = argv.pop(0)
	size_threshold = 14 * ( 1024 ** 2 )

	path = argv.pop()
	voldir = find_dir( path, '.volume' )
	print "Volume:", path, voldir
	assert voldir
	store = PathStore( voldir )
	first20 = First20Store( voldir )

	try:
		main( size_threshold, path, voldir, store, first20 )
	except KeyboardInterrupt, e:
		store.shelve.close()
		first20.shelve.close()

	store.shelve.close()

	print "FSCard %s OK" % voldir


