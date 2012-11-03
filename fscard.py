#!/usr/bin/env python
import hashlib
import os
from os.path import join, dirname, abspath, basename
import shelve
import sys
import time
import traceback

import lib
from res.fs import File, Dir, StatCache
from res.store import IndexedObject, Paths, Match, Path,\
		PathNode, sha1hash as key
import uuid


def normalize( rootdir, path, fnenc='ascii' ):
	if StatCache.isdir( path.encode( fnenc ) ):
		if not path.endswith( os.sep ):
			path += os.sep
	assert StatCache.isdir( rootdir.encode( fnenc ) )
	if not rootdir.endswith( os.sep ):
		rootdir += os.sep
	assert path.startswith( rootdir )
	path = path[ len( rootdir ): ]
	return path

def find_dir( dirpath, subleaf ):
	dirparts = dirpath.rstrip( os.sep ).split( os.sep )
	while dirparts:
		path = os.sep.join( dirparts )
		p = os.sep.join( tuple( dirparts )+( subleaf, ) )
		if StatCache.exists( p ) and StatCache.isdir( p ):
			return path + os.sep
		dirparts.pop()

def strlen( s, l ):
	if len( s ) > l:
		h = int( round( l / 2 ) )
		return s[ :h ] + '[...]' + s[ h: ]
	return s

def _do_run( path, voldir, size_threshold, size_threshold2, fnenc, f ):
	#if not File.include( f.encode( fnenc ) ):
	if StatCache.getsize( f.encode( fnenc ) ) > size_threshold:
		path = normalize( voldir, f, fnenc )
		assert isinstance( path, unicode )
		pathhash = key( path )
		guid = None 
	
		if not Paths.find( 'path', pathhash ):
			Paths.indices.path.data[ pathhash ] = path.encode( fnenc )
			if pathhash not in Paths.indices.record.data:
				guid = str( uuid.uuid4() )
				Paths.indices.record.data[ pathhash ] = guid
			else:
				guid = Paths.indices.record.data[ pathhash ]
			if guid not in Path.indices.paths.data:
				Path.indices.paths.data[ guid ] = [ ]
			Path.indices.paths.data[ guid ] += [ pathhash ]
			#assert pathhash in Path.indices.paths.data[ guid ]
			print pathhash, 'NEW ', strlen( Paths.indices.path.data[ pathhash ], 96 )
		else:
			guid = Paths.indices.record.data[ pathhash ]
			assert Paths.indices.path.data[ pathhash ] == path
			assert pathhash in Path.indices.paths.data[ guid ], path
			#assert path == Paths.indices.path.data[ pathhash ].decode( fnenc ), ( pathhash, path )
		print pathhash, ' -- ', guid

		if not StatCache.exists( f.encode( fnenc ) ):
			del Paths.indices.path.data[ pathhash ]
			del Paths.indices.record.data[ pathhash ]
			paths = Path.indices.paths.data[ guid ]
			paths.remove( pathhash )
			Path.indices.paths.data[ guid ] = paths
			print pathhash, "DEL ", path
			return

		if guid not in Path.indices.time.data:
			record_time = str( int( time.time() ) )
			Path.indices.time.data[ guid ] = record_time
		else:
			record_time = int( round( float( Path.indices.time.data[ guid ] ) ))
			if StatCache.getmtime( f.encode( fnenc ) ) <= record_time:
				pass # ok
			else:
				Path.indices.time.data[ guid ] = \
						str( round( StatCache.getmtime( f.encode( fnenc ) ) ) )
				print pathhash, ' -- ', record_time

# XXX: could keep reverse indices for Match on Path, and lookup 
# wether current path has the all the Match indices set

		size = None
		if guid not in Path.indices.size.data:
			size = StatCache.getsize( f.encode( fnenc ) )
			Path.indices.size.data[ guid ] = str( size )
		else:
			size = int( Path.indices.size.data[ guid ] )
			cur_size = StatCache.getsize( f.encode( fnenc ) ) 
			if cur_size == size:
				print pathhash, 'OK  ', lib.human_readable_bytesize( size )
				#StatCache.utime( f.encode( fnenc ), ( atime, record_time ) )
#				return
			else:
				print "size mismatch: %s vs %s" % ( size, cur_size )
				return

		print pathhash, lib.human_readable_bytesize( size )
# XXX: first20bytes is off since it cannot be useful enough
# should get more data from file, compare at byte intervals
#		f20b = open( f.encode( fnenc ) ).read( 20 )
#		if not Match.find( 'first20', f20b ):
#			Match.indices.first20.data[ f20b ] = [ guid ]
#			# rev map? Path.indices.first20.data[ guid ] = [ f20b ] 
#		else:
#			if guid not in Match.indices.first20.data[ f20b ]:
#				print "%s is first20bytes value for %r, new: %r" % (
#						Match.indices.first20.data[ f20b ], f20b, guid )

#		start = time.time()
#		cksum = lib.get_checksum_sub( f.encode( fnenc ), 'ck' )
#		dt = time.time() - start
#		if not Match.find( 'ck', cksum ):
#			Match.indices.ck.data[ cksum ] = [ guid ]
## TODO:			volume.indices.ck_cost.data[  ]
#			print guid, 'ck  ', cksum, '(%.2f s, %.4f Mb/s)' % ( dt , ( size / 1024 ** 2 ) / dt ) 
#		else:
#			if guid not in Match.indices.ck.data[ cksum ]:
#				print "possible duplicate", strlen( f.encode( fnenc ), 96 )
#				curguid = Match.indices.ck.data[ cksum ][0]
#				_dump_paths( curguid, 'ck' )
#				print guid, 'CK  ', cksum, '(%.2f s, %.4f Mb/s)' % ( dt , ( size
#					/ 1024 ** 2 ) / dt )
#				return

		start = time.time()
		sha1sum = lib.get_checksum_sub( f.encode( fnenc ) )
		dt = time.time() - start
		if not Match.find( 'sha1', sha1sum ):
			Match.indices.sha1.data[ sha1sum ] = [ guid ]
			print guid, 'sha1', sha1sum, '(%.2f s, %.4f Mb/s)' % ( dt , ( size /
				1024 ** 2 ) / dt )
		else:
			if guid not in Match.indices.sha1.data[ sha1sum ]:
				print guid, "DUPE", strlen( path, 96 )
				print Match.indices.sha1.data[ sha1sum ]
				_dump_paths( sha1sum, 'sha1' )
				print guid, 'SHA1', sha1sum, '(%.2f s, %.4f Mb/s)' % ( dt , (
					size / 1024 ** 2 ) / dt )
				return

#		start = time.time()
#		md5sum = lib.get_checksum_sub( f.encode( fnenc ), 'md5' )
#		dt = time.time() - start
#		if not Match.find( 'md5', md5sum ):
#			Match.indices.md5.data[ md5sum ] = [ guid ]
#			print guid, 'md5 ', md5sum, '(%.2f s, %.4f Mb/s)' % ( dt , ( size / 1024 ** 2) / dt )
#		else:
#			if guid not in Match.indices.md5.data[ md5sum ]:
#				print "possible duplicate", strlen( f.encode( fnenc ), 96 )
#				_dump_paths( md5sum, 'md5' )
#				print guid, 'MD5 ', md5sum, '(%.2f s, %.4f Mb/s)' % ( dt , ( size / 1024 ** 2 ) / dt )
#				return

		start = time.time()
		sparsesum = hashlib.sha1( lib.get_sparsesum( 128, f.encode( fnenc ))
				).hexdigest()
		dt = time.time() - start
		if not Match.find( 'sparse', sparsesum ):
			Match.indices.sparse.data[ sparsesum ] = [ guid ]
			print guid, 'SPRS', sparsesum, '(%.2f s, %.4f Mb/s)' % ( dt , ( size / 1024 ** 2) / dt )
		else:
			if guid not in Match.indices.sparse.data[ sparsesum ]:
				print guid, "DUPE", strlen( path, 96 )
				_dump_paths( sparsesum, 'sparse' )
				print guid, 'SPRS', sparsesum, '(%.2f s, %.4f Mb/s)' % ( dt , ( size / 1024 ** 2 ) / dt )
				return

		return True

def _dump_paths( key, index ):
	curguids = getattr( Match.indices, index ).data[ key ]
	updated = False
	for curguid in curguids:
		if curguid not in Path.indices.paths.data:
			print "GUID %s from index %s has no known paths" % ( curguid, index )
			curguids.remove( curguid )
			updated = True
	#					assert curguid in Path.indices.record.data
		else:
			for x in Path.indices.paths.data[ curguid ]:
				print curguid, 'Path.paths', Paths.indices.path.data[ x ]
	if updated:
		getattr( Match.indices, index ).data[ key ] = curguids

def _do_cleanup( path, voldir, fnenc, f ):
	path = normalize( dirname( voldir ), f, fnenc )
	pathhash = key( path )
	guid = None

	if Paths.find( 'path', pathhash ):
		del Paths.indices.path.data[ pathhash ]
	if Paths.find( 'record', pathhash ):
		del Paths.indices.record.data[ pathhash ]


class WalkCounter(dict):
	def __init__( self, path, file_threshold=1000 ):
		dict.__init__( self )
		self.keys = []
		self.last_total = 0
		self.file_threshold = file_threshold
		self.push( path )
	def is_sub( self, dirpath ):
		return dirpath.startswith( self.key )
	def is_parent( self, dirpath ):
		return self.key.startswith( dirpath )
	def is_neighbour( self, dirpath ):
		if dirpath and self.key:
			p = 0
			maxlen = max( ( len( dirpath ), len( self.key ) ) )
			while dirpath[:p] == self.key[:p]:
				p += 1
				if p == maxlen:
					break
			p -= 1
			tails = ( dirpath[p:], self.key[p:] )
			return ( os.sep not in tails[0] ) and ( os.sep not in tails[1] )
	@property
	def total( self ):
		c = self.last_total
		for k in self.keys:
			c += self[ k ]
		return c
	@property
	def cnt( self ):
		return self[ self.key ]
	@property
	def key( self ):
		assert self.keys, self
		return self.keys[ -1 ]
	@property
	def level( self ):
		return len( self.keys )
	@property
	def name( self ):
		return basename( self.key )
	def push( self, fpath ):
		assert fpath not in self
		assert fpath not in self.keys
		self.keys.append( fpath )
		self[ self.key ] = 0
	def pop( self ):
		assert self.keys, self
		cnt = self.cnt
		del self[ self.key ]
		self.keys.pop()
		self[ self.key ] += cnt
	def count( self ):
		self[ self.key ] += 1
	@property
	def triggered( self ):
		return self.cnt > self.file_threshold
	def reset( self ):
		self.last_total += self.cnt
		self[ self.key ] = 0

def main( path, voldir ):
	size_threshold = 14 * ( 1024 ** 2 ) # noise threshold
	size_threshold2 = 14 * ( 1024 ** 3 ) # extreme high bound for bad ideas
	fnenc = 'utf-8'
	st = time.time()
	w_opts = Dir.walk_opts
	w_opts.recurse = True
	# start counting at root
	counter = WalkCounter( path )
	def _size_threshold( path ):
		size = StatCache.getsize( path )
		if not size: 
			return
		if size > size_threshold2:
			print 'Skipping too large file for now', path 
			return
		if size > size_threshold:
			return True
	file_filters = [ _size_threshold ]
	dir_filters = [ PathNode.is_dirty ]
#	print 'Walking', path
	for f in Dir.walk( path, w_opts, ( file_filters, dir_filters ) ):
		ft = time.time()
		# walk top down, depth first
		fenc = f.encode( fnenc )

		if StatCache.isdir( fenc ):
			if not fenc[ -1 ] == os.sep:
				f += os.sep

			#print counter.level * '\t', counter.name, counter.total, counter.cnt
			if fenc == counter.key:
				pass
			else:
				if not counter.is_sub( fenc ):
#					print "left", counter.key
					if counter.triggered:
						counter.reset()
						PathNode.update_walk( f, fnenc )
#						print 'reset', counter.total
					counter.pop()
				if counter.is_sub( fenc ):
					counter.push( fenc )
#					print "enter", counter.key
			#print counter.level * '\t', counter.name, counter.total, counter.cnt
			continue

		counter.count()
		print "File", f, counter.total
		
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

		rt = time.time() - st
		if v:
			print 'Path %i done (%2.f / %2.f s). ' % ( counter.total, time.time() - ft , rt )
			print
			v = False
		elif not counter.total % 1000:
			print "Path %s.. (%.2f s)" % ( counter.total, rt )
			#sys.stdout.write("%s.. "%cnt)
			#sys.stdout.flush()

	counter.pop()
	#print "left", counter.key
	if counter.triggered:
		counter.reset()
	#print "Finished", path, counter.keys, counter.total
	assert counter.keys
	#print "OK", path, counter.total

def main_full():
	argv = list( sys.argv )
	script_name = argv.pop(0)

	path = abspath( argv.pop() )

	#Volumes.init( userdir )
	voldir = find_dir( path, '.cllct' )
	#volguid = Volumes.find( 'record', voldir )
	#volume = Volume.load( volguid )

	print "Volume:", voldir
	assert voldir

	PathNode.init( voldir )
	Paths.init( voldir )
	Path.init( voldir )
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

def main_update_pathindexes():
	argv = list( sys.argv )
	script_name = argv.pop(0)

	path = abspath( argv.pop() )

	#Volumes.init( userdir )
	voldir = find_dir( path, '.cllct' )
	#volguid = Volumes.find( 'record', voldir )
	#volume = Volume.load( volguid )

	print "Volume:", voldir
	assert voldir

	PathNode.init( voldir )
	Paths.init( voldir )
	Path.init( voldir )
	Match.init( voldir )

	for pathhash in Paths.indices.record.data:
		print 'Path.record', pathhash
		try:
			assert pathhash in Paths.indices.path.data
			path = Paths.indices.path.data[ pathhash ]
			assert isinstance( path, unicode ), path
		except KeyboardInterrupt, e:
			print 'Interrupted'
			break
		except Exception, e:
			print
			print 'Failure: '
			traceback.print_exc()
	for guid in Path.indices.paths.data:
		print 'Path.paths', guid
		try:
			pathhash_list = Path.indices.paths.data[ guid ]
			updated = False
			for pathhash in pathhash_list:
				if pathhash not in Paths.indices.path.data:
					pathhash_list.remove( pathhash )
					updated = True
				elif pathhash not in Paths.indices.record.data:
					Paths.indices.record.data[ pathhash ] = guid
				else:
					assert Paths.indices.record.data[ pathhash ] == guid
			if updated:
				Path.indices.paths.data[ guid ] = pathhash_list
#			assert pathhash_list, guid
		except KeyboardInterrupt, e:
			print 'Interrupted'
			break
		except Exception, e:
			print
			print 'Failure: '
			traceback.print_exc()
	remove = []
	for pathhash in Paths.indices.path.data:
		print 'Paths.path', pathhash
		try:
			assert pathhash in Paths.indices.record.data
			path = Paths.indices.path.data[ pathhash ]
			if not isinstance( path, unicode ):
				remove.append( pathhash )
				continue
			assert isinstance( path, unicode ), path
			print pathhash, path
			guid = Paths.indices.record.data[ pathhash ]
			print guid, pathhash
			if guid not in Path.indices.paths.data:
				Path.indices.paths.data[ guid ] = []
			l = Path.indices.paths.data[ guid ]
			if path not in l:
				l.append( path )
				Path.indices.paths.data[ guid ] = l
		except KeyboardInterrupt, e:
			print 'Interrupted'
			break
		except Exception, e:
			print
			print 'Failure: '
			traceback.print_exc()

	for pathhash in remove:
		del Paths.indices.path.data[ pathhash ]
		if pathhash in Paths.indices.record.data:
			del Paths.indices.record.data[ pathhash ]

	IndexedObject.close()


if __name__ == '__main__':

	#main_update_pathindexes() # Paths[pathhash]=path where path in Path.paths
	main_full()


