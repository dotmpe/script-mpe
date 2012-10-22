"""

"""
import os
import sys
from os.path import join, isdir, expanduser
import anydbm
import hashlib
import shelve

import lib
import confparse


class Value:

	" obj.class.index[ key ] -- value "

	def __init__( self, klass, attr, path ):
		self.klass = klass
		self.attr = attr
		self.data = lib.get_index( path )

class ListValue:

	" obj.class.index[ key ] -- [ value ] "

	def __init__( self, klass, attr, path ):
		self.klass = klass
		self.attr = attr
		self.data = shelve.open( path )

class OneToMany_TwoWay:

	" key   -*  value "
	" value *-  key "

class IndexedObject:

	indices_spec = ()

	indices = None
	stores = None

	@classmethod
	def init( clss, voldir ):
		clss.indices = confparse.Values({})
		if not IndexedObject.stores:
			IndexedObject.stores = confparse.Values({})
		vol = join( voldir, ".volume" )
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
	def find( clss, idx, key ):
		if idx not in clss.indices:
			return
		if key not in clss.indices[ idx ].data:
			return
		return clss.indices[ idx ].data[ key ]

	@classmethod
	def set( clss, idx, key, value ):
		assert idx in clss.indices
		clss.indices[ idx ].data[ key ] = value

	@classmethod
	def close( clss ):
		for idx in clss.stores:
			clss.stores[ idx ].data.close()
			print 'Closed', idx

class Volume( IndexedObject ):
	"""
	Just for the rootdir.

	~/.cllct/volumes.db::
		pathhash	  --  voldir

	"""
	indices_spec = (
			( 'vpath', Value ),
		)

class Path( IndexedObject ):
	"""
	For known files.

	path (.volume/fsref.db)::

		<pathhash>  --  <path>

	record (.volume/fscontent.db)::

		<pathhash>  *-  <guid>
	"""
	indices_spec = (
			( 'path', Value ),
			( 'record', Value ),
		)

	key = 'pathhash'

	@staticmethod
	def pathhash( obj ):
		return hashlib.sha1( obj ).hexdigest()

class Record ( IndexedObject ):
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
			( 'descr', Value ),
			( 'time', Value ),
			( 'size', Value ),
		)

class Match( IndexedObject ):
	"""
	.volume/<hashtype>.db

		<contenthash>  -*  <guid>

	# find list of possible guids
	.volume/first20.db		first20bytes  =*  guid
	.volume/sha1.db		   sha1sum	   =*  guid
	"""
	indices_spec = (
			( 'first20', ListValue, ),
			( 'sha1', ListValue, ),
			( 'md5', ListValue, ),
			( 'ck', ListValue, ),
	)

