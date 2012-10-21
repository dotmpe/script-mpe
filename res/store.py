"""

	The object API is:
		>>> assert Klass.key() == "myidx"
		>>> myobj = Klass.indices.myidx[key] 
		>>> myobj == Klass.fetch('myidx', key)
		True
		>>> myobj.myidx == key
		True
		>>> myobj.myidx2 
		'key2'
mpo		>>> myobj == Klass.fetch( 'myidx2', 'key2' )
		>>> Klass.indices
		Attrs( myidx = Value, myidx2=Value )
		>>> Klass2.indices
		Attrs( myrev = OneToMany_TwoWay,  )

		>>> myobj.attr = 'update' # XXX detect and commit on close
		>>> myobj.commit() #or 
		>>> Klass.store[key] = myobj; Klass.store.sync() #?

	and the index API:				
		>>> obj2 = Klass.fetch('sha1', 'abcdef') # raise keyerr if not found
		>>> obj3 = Klass.find('sha1', 'abcdef') # return none if not found

	and the bare shelves:
		>>> key = Klass.indices.{sha1,tth,..}[value]
		>>> keys = Klass.indices.{size,crc,type}[value]

	usage:
		>>> obj = Klass(new_key)
		>>> obj.sha1 = 'abcdef'
		>>> obj.commit()
		>>> obj == obj2 == obj3 
		True

"""
import os
import sys
from os.path import join, isdir, expanduser
import anydbm
import hashlib
import shelve

import confparse


def get_index( path, mode='w' ):
	print 'get_index', path, mode
	if not os.path.exists( path ):
		assert 'w' in mode
		try:
			anydbm.open( path, 'n' ).close()
		except Exception, e:
			raise Exception( "Unable to create new resource DB at <%s>: %s" %
					( path, e ) )
	try:
		return anydbm.open( path, mode )
	except anydbm.error, e:
		raise Exception( 
				"Unable to access resource DB at <%s>: %s" %
				( path, e ) )

class Value:

	" obj.class.index[ key ] -- value "

	def __init__( self, klass, attr, path ):
		self.klass = klass
		self.attr = attr
		self.data = get_index( path )

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
			index = idx_class( clss, attr_name, join( vol, "%s.db" % attr_name ) )
			# XXX
			cn = clss.__name__
			setattr( IndexedObject.stores, "%s.%s"%( cn, attr_name ), index )
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
	)

def main():
	args = list( sys.argv )
	script_name = args.pop(0)
	path = args.pop()
	from fscard import find_dir
	voldir = find_dir( path, '.volume' )
	assert voldir
	userdir = expanduser( "~/.cllct/" )
#	Volume.init( userdir )
#	vol = Volume.fetch( 'vpath', voldir )
	File.init( voldir )
	Record.init( voldir )
	Match.init( voldir )
   
if __name__ == '__main__':
	main()

