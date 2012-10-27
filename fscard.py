#!/usr/bin/env python
import hashlib
import os
from os.path import join, isdir, getsize, dirname, abspath
import shelve
import sys
import time
import traceback

import lib
from res.store import IndexedObject, Path, Match, Record, pathhash as key
from res.fs import File, Dir
import uuid


def normalize( rootdir, path, fnenc='ascii' ):
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
	dirparts = dirpath.rstrip( os.sep ).split( os.sep )
	while dirparts:
		path = os.sep.join( dirparts )
		if isdir( os.sep.join( tuple( dirparts )+( subleaf, ) ) ):
			return path + os.sep
		dirparts.pop()

def strlen( s, l ):
	if len( s ) > l:
		h = int( round( l / 2 ) )
		return s[ :h ] + '[...]' + s[ h: ]
	return s

def _do_run( path, voldir, size_threshold, size_threshold2, fnenc, f ):
	#if not File.include( f.encode( fnenc ) ):
	if getsize( f.encode( fnenc ) ) > size_threshold2:
		print 'Skipping too large file for now', f.encode( fnenc )
		return
	if getsize( f.encode( fnenc ) ) > size_threshold:
		path = normalize( voldir, f, fnenc )
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
			print pathhash, 'NEW ', strlen( Path.indices.path.data[ pathhash ], 96 )
		else:
			guid = Path.indices.record.data[ pathhash ]
			#assert path == Path.indices.path.data[ pathhash ].decode( fnenc ), ( pathhash, path )
		print pathhash, ' -- ', guid

		if not os.path.exists( f.encode( fnenc ) ):
			del Path.indices.path.data[ pathhash ]
			del Path.indices.record.data[ pathhash ]
			paths = Record.indices.paths.data[ guid ]
			paths.remove( pathhash )
			Record.indices.paths.data[ guid ] = paths
			print pathhash, "DEL ", path
			return

		if guid not in Record.indices.time.data:
			record_time = str( int( time.time() ) )
			Record.indices.time.data[ guid ] = record_time
		else:
			record_time = int( round( float( Record.indices.time.data[ guid ] ) ))
			if os.path.getmtime( f.encode( fnenc ) ) <= record_time:
				pass # OK
			else:
				Record.indices.time.data[ guid ] = \
						str( round( os.path.getmtime( f.encode( fnenc ) ) ) )
				print pathhash, ' -- ', record_time

# XXX: could keep reverse indices for Match on Record, and lookup 
# wether current Record has the all the Match indices set

		size = None
		if guid not in Record.indices.size.data:
			size = os.path.getsize( f.encode( fnenc ) )
			Record.indices.size.data[ guid ] = str( size )
		else:
			size = int( Record.indices.size.data[ guid ] )
			cur_size = os.path.getsize( f.encode( fnenc ) ) 
			if cur_size == size:
				print pathhash, 'OK  ', lib.human_readable_bytesize( size )
				#os.utime( f.encode( fnenc ), ( atime, record_time ) )
				return
			else:
				print "Size mismatch: %s vs %s" % ( size, cur_size )
				return

		print pathhash, lib.human_readable_bytesize( size )
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

		start = time.time()
		cksum = lib.get_checksum_sub( f.encode( fnenc ), 'ck' )
		dt = time.time() - start
		if not Match.find( 'ck', cksum ):
			Match.indices.ck.data[ cksum ] = [ guid ]
			print guid, 'CK  ', cksum, '(%.2f sec)' % dt 
		else:
			if guid not in Match.indices.ck.data[ cksum ]:
				print "Possible duplicate", strlen( f.encode( fnenc ), 96 )
				curguid = Match.indices.ck.data[ cksum ][0]
				for x in Record.indices.paths.data[ curguid ]:
					print Path.indices.path.data[ x ]
				print guid, 'CK  ', cksum, '(%.2f sec)' % dt 
				return

		start = time.time()
		sha1sum = lib.get_checksum_sub( f.encode( fnenc ) )
		dt = time.time() - start
		if not Match.find( 'sha1', sha1sum ):
			Match.indices.sha1.data[ sha1sum ] = [ guid ]
			print guid, 'SHA1', sha1sum, '(%.2f sec)' % dt 
		else:
			if guid not in Match.indices.sha1.data[ sha1sum ]:
				print "Possible duplicate", strlen( f.encode( fnenc ), 96 )
				curguid = Match.indices.sha1.data[ sha1sum ][0]
				for x in Record.indices.paths.data[ curguid ]:
					print Path.indices.path.data[ x ]
				print guid, 'SHA1', sha1sum, '(%.2f sec)' % dt 
				return

		start = time.time()
		md5sum = lib.get_checksum_sub( f.encode( fnenc ), 'md5' )
		dt = time.time() - start
		if not Match.find( 'md5', md5sum ):
			Match.indices.md5.data[ md5sum ] = [ guid ]
			print guid, 'MD5 ', md5sum, '(%.2f sec)' % dt 
		else:
			if guid not in Match.indices.md5.data[ md5sum ]:
				print "Possible duplicate", strlen( f.encode( fnenc ), 96 )
				curguid = Match.indices.md5.data[ md5sum ][0]
				for x in Record.indices.paths.data[ curguid ]:
					print Path.indices.path.data[ x ]
				print guid, 'MD5 ', md5sum, '(%.2f sec)' % dt 
				return

		return True

def _do_cleanup( path, voldir, fnenc, f ):
	path = normalize( dirname( voldir ), f, fnenc )
	pathhash = key( path.encode( fnenc ) )
	guid = None

	if Path.find( 'path', pathhash ):
		del Path.indices.path.data[ pathhash ]
	if Path.find( 'record', pathhash ):
		del Path.indices.record.data[ pathhash ]


def main( path, voldir ):
	size_threshold = 14 * ( 1024 ** 2 ) # noise threshold
	size_threshold2 = 14 * ( 1024 ** 3 ) # extreme high bound for bad ideas
	fnenc = 'utf-8'
	w_opts = Dir.walk_opts
	w_opts.recurse = True
	cnt = 0
	print 'Walking', path
	for f in Dir.walk( path, w_opts ):

		if isdir( f.encode( fnenc ) ):
			continue

		cnt += 1

		v = False

		try:
			v = _do_run( path, voldir, size_threshold, size_threshold2, fnenc, f )
		except UnicodeDecodeError, e:
			_do_cleanup( path, voldir, fnenc, f )
		except KeyboardInterrupt, e:
			_do_cleanup( path, voldir, fnenc, f )
			raise
		except Exception, e:
			_do_cleanup( path, voldir, fnenc, f )
			traceback.print_exc()
			raise

		#if cnt == 1000:
		#	sys.stdout.write( "Files: ")
		if v:
			print 'File %i done. ' % cnt
			print
			v = False
		elif not cnt % 1000:
			print "File %s.. "%cnt
			#sys.stdout.write("%s.. "%cnt)
			#sys.stdout.flush()


if __name__ == '__main__':

	argv = list( sys.argv )
	script_name = argv.pop(0)

	path = abspath( argv.pop() )
	voldir = find_dir( path, '.volume' )

	print "Volume:", voldir
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

