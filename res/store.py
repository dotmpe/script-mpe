"""

"""
import os
import sys
from os.path import join, expanduser, dirname
import anydbm
import hashlib
import shelve

import lib
import confparse
from res.fs import Dir, StatCache


def sha1hash( obj ):
	assert isinstance( obj, unicode )
	return hashlib.sha1( obj.encode( 'utf-8' ) ).hexdigest()

#pathhash = sha1hash

class Value:

	" obj.class.index[ key ] -- value "

	def __init__( self, klass, attr, path, _type=str ):
		self.klass = klass
		self.attr = attr
		self.data = lib.get_index( path )
		self.tp = _type

	def get( self, key ):
		return self.tp( self.data[ key ] )

class Float( Value ):
	def __init__( self, klass, attr, path ):
		super( Float, self ).__init__( klass, attr, path, _type=float )

class ListValue:

	" obj.class.index[ key ] -- [ value1, ] "

	def __init__( self, klass, attr, path ):
		self.klass = klass
		self.attr = attr
		self.data = shelve.open( path )

class OneToMany_TwoWay:

	" key   -*  value "
	" value *-  key "


class IndexedObject:

	"""
	 keyidx[ key ] = keyvalue
	 valueidx[ keyvalue ] = IndexedObject(
		idx[ key ] => keytype( key ) / value
	 )
	"""

	indices_spec = ()

	indices = None
	stores = None

	def __init__( self, key, value ):
		pass
#		clss = self.__class__
#		clss.default[  ]
#		IndexedObject.stores

	@classmethod
	def init( clss, voldir ):
		clss.indices = confparse.Values({})
		if not IndexedObject.stores:
			IndexedObject.stores = confparse.Values({})
		if not Dir.issysdir( voldir ):
			vol = join( voldir, ".cllct" )
		else:
			vol = voldir
			voldir = dirname( vol.rstrip( os.sep ) )
		for idx in clss.indices_spec:
			attr_name, idx_class = idx[ : 2 ]
			cn = clss.__name__
			store_name = "%s_%s"%( cn, attr_name ) # XXX: this would depend ondirection (if expanding index facade)
			index = idx_class( clss, attr_name, join( vol, "%s.db" % store_name ) )
			# XXX
			setattr( IndexedObject.stores, store_name, index )
#			if len( idx ) == 4:
#				rev_class, rev_attr = idx[ 2 : ]
#				index = idx_class( 
#						klass1, attr_name, join( voldir, "%s.db" % attr_name),
#						klass2, rev_attr, join( voldir, "%s.db" % rev_attr ) )
			setattr( clss.indices, attr_name, index )

	@classmethod
	def default( clss ):
		return clss.indices[ clss.key ]

	@classmethod
	def find( clss, *args ):
		if len(args) == 1:
			args = ( clss.key, )+ args
			return clss.find( *args )
		idx, key = args
		if idx not in clss.indices:
			return
		if key not in clss.indices[ idx ].data:
			return
		return clss.indices[ idx ].data[ key ]

	@classmethod
	def fetch( clss, idx, key ):
		v = clss.find( idx, key )
		if not v:
			raise KeyError, "No such item %s.%s [ %s ] " % ( clss.__name__, idx, key )
		return v

	# XXX: new code
	@classmethod
	def load( clss, idx, key ):
		v = clss.fetch( idx, key )
		return clss( v )
	# /xxx

	@classmethod
	def set( clss, idx, key, value ):
		assert idx in clss.indices
		clss.indices[ idx ].data[ key ] = value

	@classmethod
	def close( clss ):
		for idx in clss.stores:
			clss.stores[ idx ].data.close()
			print 'Closed', idx

class Volumes( IndexedObject ):
	"""
	Just for the rootdir.

	Volume.vpath (~/.cllct/volumes.db)::
		pathhash	  --  voldir
	Volume.record
		pathhash	  --  guid
	"""
	indices_spec = (
			( 'vpath', Value ),
			( 'record', Value ),
	)
	key_type = 'pathhash'

class Volume( IndexedObject ):
	"""
	Just for the rootdir.

	Volume.ck_cost
		guid          --  0.2
	Volume.size
		guid          --  112 bytes (file contents; actual data)
	Volume.fs_size
		guid          --  11 bytes (file meta; inode structure)
	Volume.sys_size
		guid          --  000 bytes (system files; classified non-user data)

	Volume.space_used
		guid          --  321 bytes (from blocks; size + fs meta)
	Volume.space_available
		guid          --  123 bytes (from blocks)
	Volume.space_usage
		guid          --  66.67%
	"""
	indices_spec = (
#			( 'vpath', Value ),
# because we do not know where the volume is located physically,
# we keep a locally recorded avg cost in  sec / GB
			( 'ck_cost', Float ),
			( 'sha1_cost', Float ),
			( 'md5_cost', Float ),
		)
	#key = 'Volumes.vpath' [ Volumes.key ] = self.key_type( self.key )
	key_type = 'guid'

class PathNode( IndexedObject ):
	"""
	Metadata for large folders. 
	path::

		<pathhash>  --  <path>

	descr::
	
		<pathhash>  --  <descr>

	time::
	
		<pathhash>  --  <timestamp>
	"""
	indices_spec = (
			( 'path', Value ),
			( 'time', Value ),
			( 'size', Value ), # TODO: integrate
		)
	key_type = 'guid'
	@classmethod
	def is_dirty( clss, path ):
		"True for either new or update"
		path = StatCache.init( path )
		assert isinstance( path, unicode )
		pathhash = sha1hash( path )
		if pathhash in PathNode.indices.time.data:
			record_time = int( round( float( PathNode.indices.time.data[ pathhash ] ) ))
			if StatCache.getmtime( f.encode( fnenc ) ) <= record_time:
				return False
			else:
				PathNode.indices.time.data[ pathhash ] = \
						str( round( StatCache.getmtime( f.encode( fnenc ) ) ) )
				print pathhash, ' -- ', record_time
		return True
	@classmethod
	def init_record( clss, path ):
		path = StatCache.init( path )
		assert isinstance( path, unicode )
		pathhash = sha1hash( path )
		fnenc = 'utf-8'
		if not clss.find( 'path', pathhash ):
			clss.indices.path.data[ pathhash ] = path.encode( fnenc )
			#assert pathhash in Path.indices.paths.data[ pathhash ]
			print pathhash, 'NEW ', strlen( clss.indices.path.data[ pathhash ], 96 )
		else:
			path = clss.indices.record.data[ pathhash ].decode( fnenc )
	@classmethod
	def update_walk( clss, path ):
		path = StatCache.init( path )
		assert isinstance( path, unicode )
		pathhash = sha1hash( path )
		fnenc = 'utf-8'
		if pathhash not in PathNode.indices.time.data:
			clss.init_record( path )
			record_time = str( int( time.time() ) )
			PathNode.indices.time.data[ pathhash ] = record_time
			return True
		else:
			record_time = int( round( float( PathNode.indices.time.data[ pathhash ] ) ))
			if StatCache.getmtime( f.encode( fnenc ) ) <= record_time:
				return False
			else:
				PathNode.indices.time.data[ pathhash ] = \
						str( round( StatCache.getmtime( f.encode( fnenc ) ) ) )
				print pathhash, ' -- ', record_time
				return True

class Paths( IndexedObject ):
	"""
	For known files.

	path (.volume/Paths_path.db)::

		<pathhash>  --  <path>

	record (.volume/Paths_record.db)::

		<pathhash>  *-  <guid>
	"""
	indices_spec = (
			( 'path', Value ),
			( 'record', Value ),
#           ( 'record', Path.guid )
		)
	key = 'path'
	key_type = 'pathhash'

class Path( IndexedObject ):
	"""
	paths (.volume/content.db)::
	
		<guid>   -*   <pathhash>

	descr (card.db)::
	
		<guid>  --  <descr>

	time (card-timestamp.db)::
	
		<guid>  --  <timestamp>
	"""
	indices_spec = (
			( 'paths', ListValue, ),
#           ( 'paths', list(Paths.path) )
			( 'descr', Value ),
			( 'time', Value ),
			( 'size', Value ),
		)
	key_type = 'guid'

class Match( IndexedObject ):
	"""
	.volume/<hashtype>.db

		<contenthash>  -*  <guid>

	# find list of possible guids
	.volume/first20.db		first20bytes  =*  guid
	.volume/sha1.db		   sha1sum	   =*  guid
	"""
	indices_spec = (
#			( 'first20', ListValue, ), XXX: need new heuristic, must be faster than cksum
			( 'sha1', ListValue, ),
			( 'md5', ListValue, ),
			( 'ck', ListValue, ),
			( 'sparse', ListValue, ),
	)

