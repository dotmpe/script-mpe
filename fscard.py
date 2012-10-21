import hashlib
import os
from os.path import join, isdir, getsize, dirname
import shelve
import sys
import time
import traceback

import lib
from res.store import IndexedObject, Path, Match, Record
from res.fs import Dir
import uuid


def key( obj ):
	return hashlib.sha1( obj ).hexdigest()

def normalize( rootdir, path, fnenc ):
	if isdir( path.encode( fnenc ) ):
		if not path.endswith( os.sep ):
			path += os.sep
	assert isdir( rootdir.encode( fnenc ) )
	if not rootdir.endswith( os.sep ):
		rootdir += os.sep
	assert path.startswith( rootdir )
	path = path[ len( rootdir ): ]
	return path

def find_dir( dirpath, subleaf ):
	dirparts = dirpath.split( os.sep )
	while dirparts:
		path = os.sep.join( dirparts )
		if isdir( os.sep.join( tuple( dirparts )+( subleaf, ) ) ):
			return path
		dirparts.pop()

def strlen( s, l ):
	if len( s ) > l:
		h = int( round( l / 2 ) )
		return s[ :h ] + '[...]' + s[ h: ]
	return s

def _do_run( path, voldir, size_threshold, size_threshold2, fnenc, f ):
	if 'p0rn' not in f and getsize( f.encode( fnenc ) ) > size_threshold2:
		print 'Skipping too large file for now', f.encode( fnenc )
		return
	if getsize( f.encode( fnenc ) ) > size_threshold:
		path = normalize( dirname( voldir ), f, fnenc )
		pathhash = key( path.encode( fnenc ) )
		guid = None

		if not Path.find( 'path', pathhash ):
			Path.indices.path.data[ pathhash ] = path.encode( fnenc )
			if pathhash not in Path.indices.record.data:
				guid = str( uuid.uuid4() )
				Path.indices.record.data[ pathhash ] = guid
			else:
				guid = Path.indices.record.data[ pathhash ]
			if guid not in Record.indices.paths.data:
				Record.indices.paths.data[ guid ] = [ ]
			Record.indices.paths.data[ guid ] += [ pathhash ]
			#assert pathhash in Record.indices.paths.data[ guid ]
			print pathhash, strlen( Path.indices.path.data[ pathhash ], 128 ), 'NEW'
		else:
			guid = Path.indices.record.data[ pathhash ]
			#assert path == Path.indices.path.data[ pathhash ].decode( fnenc ), ( pathhash, path )
		if not os.path.exists( f.encode( fnenc ) ):
			del Path.indices.path.data[ pathhash ]
			del Path.indices.record.data[ pathhash ]
			paths = Record.indices.paths.data[ guid ]
			paths.remove( pathhash )
			Record.indices.paths.data[ guid ] = paths
			print "Removed deleted from indices", path
			return

		if guid not in Record.indices.time.data:
			Record.indices.time.data[ guid ] = str( time.time() )
		else:
			recordtime = float( Record.indices.time.data[ guid ] )
			if os.path.getmtime( f.encode( fnenc ) ) < recordtime:
#				print pathhash, 'OK'
				return

		if guid not in Record.indices.size.data:
			Record.indices.size.data[ guid ] = str( os.path.getsize( f.encode( fnenc ) ) )
		else:
			size = float( Record.indices.size.data[ guid ] )
			if os.path.getsize( f.encode( fnenc ) ) == size:
				print pathhash, 'OK'
				os.utime( f.encode( fenc ) )
				return

# XXX: first20bytes is off since it cannot be useful enough
# should get more data from file, compare at byte intervals
#		f20b = open( f.encode( fnenc ) ).read( 20 )
#		if not Match.find( 'first20', f20b ):
#			Match.indices.first20.data[ f20b ] = [ guid ]
#			# rev map? Record.indices.first20.data[ guid ] = [ f20b ] 
#		else:
#			if guid not in Match.indices.first20.data[ f20b ]:
#				print "%s is first20bytes value for %r, new: %r" % (
#						Match.indices.first20.data[ f20b ], f20b, guid )

		md5sum = lib.get_checksum_sub( f, 'md5' )
		if not Match.find( 'md5', md5sum ):
			Match.indices.md5.data[ md5sum ] = [ guid ]
			print guid, 'MD5'
		else:
			if guid not in Match.indices.md5.data[ md5sum ]:
				print "%s is md5sum value for %r, new: %r" % (
						Match.indices.md5.data[ md5sum ], md5sum, guid )
				return

		sha1sum = lib.get_checksum_sub( f.encode( fnenc ) )
		if not Match.find( 'sha1', sha1sum ):
			Match.indices.sha1.data[ sha1sum ] = [ guid ]
			print guid, 'SHA1'
		else:
			if guid not in Match.indices.sha1.data[ sha1sum ]:
				print "%s is value for %r, new: %r" % (
						Match.indices.sha1.data[ sha1sum ], sha1sum, guid )
				return

def _do_cleanup( path, voldir, fnenc, f ):
	path = normalize( dirname( voldir ), f, fnenc )
	pathhash = key( path.encode( fnenc ) )
	guid = None

	if Path.find( 'path', pathhash ):
		del Path.indices.path.data[ pathhash ]
	if Path.find( 'record', pathhash ):
		del Path.indices.record.data[ pathhash ]


def main( path, voldir ):
	size_threshold = 14 * ( 1024 ** 2 )
	size_threshold2 = 50 * ( 1024 ** 2 )
	fnenc = 'utf-8'
	w_opts = Dir.walk_opts
	w_opts.recurse = True
	cnt = 0
	for f in Dir.walk( path, w_opts ):

		if isdir( f.encode( fnenc ) ):
			continue

		cnt += 1

		try:
			_do_run( path, voldir, size_threshold, size_threshold2, fnenc, f )
		except KeyboardInterrupt, e:
			_do_cleanup( path, voldir, fnenc, f )
			raise
		except Exception, e:
			_do_cleanup( path, voldir, fnenc, f )
			traceback.print_exc()
			raise

		if cnt == 1000:
			sys.stdout.write( "Files: ")
		if not cnt % 1000:
			sys.stdout.write("%s.. "%cnt)
			sys.stdout.flush()


if __name__ == '__main__':

	argv = list( sys.argv )
	script_name = argv.pop(0)

	path = argv.pop()
	voldir = find_dir( path, '.volume' )

	print "Volume:", path, voldir
	assert voldir

	Path.init( voldir )
	Record.init( voldir )
	Match.init( voldir )

	try:
		main( path, voldir )
	except KeyboardInterrupt, e:
		print 'Interrupted'
	except Exception, e:
		print
		print 'Program failure: '
		traceback.print_exc()

	IndexedObject.close()

