#!/usr/bin/env python
"""tree - Creates a tree of a filesystem hierarchy.

Calculates cumulative space of each directory. Output in JSON format.

Copyleft, May 2007.  B. van Berkum <berend `at` dotmpe `dot` com>

Updates
-------
October 2012
	- using blksize to calculate actual occupied disk space.
	- a too detailed storage will drag performance. The current operations
	  per file are constant, so file count is the limiting factor.

TODO: the storage should create a report for some directory, sorry about
	threshold later.

"""
"""Create a tree of the filesystem using dicts and lists.

	All filesystem nodes are dicts so its easy to add attributes.
	One key is the filename, the value of this key is None for files,
	and a list of other nodes for directories. Eg::

		{'rootdir': [
			{'filename1':None},
			{'subdir':[
				{'filename2':None}
			]}
		]}
	"""

"""

Caching structured

Filetree prototype: store paths in balanced, traversable tree structure 
for easy, fast and space efficient
index trees of filesystem (and other hierarchical structrures).

Introduction
______________________________________________________________________________
Why? Because filepath operations on the OS are generally far more optimized
than native code: only for extended sets some way of parallel (caching) 
structure may optimize performance. However since filesystem hierarchies are 
not balanced we want to avoid copying (parts) of the unbalanced structure to 
our index.

Operations on each file may be fairly constant when dealing with the descriptor,
or depend on file size. The calling API will need to determine when to create 
new nodes.

Treemap accumulates the filecount, disk usage and file sizes onto all directory
nodes in the tree. Conceptually it may be used as an enfilade with offsets and
widths?


Implementation
______________________________________________________________________________
Below is the code where Node implements the interface to the stored data,
and a separate Key implementation specifies the index properties of it.
Volume is the general session API which is a bit immature, but does store
and reload objects. Storage itself is a simple anydb with json encoded data.



"""
import sys
import os
import shelve
from pprint import pformat
from os import listdir, stat, lstat
from os.path import join, exists, islink, isdir, getsize, basename, dirname, \
	expanduser, realpath
try:
	# @bvb: simplejson thinks it should be different and deprecated read() and write()
	# not sure why... @xxx: simplejson has UTF-8 default, json uses ASCII I think?
	from simplejson import dumps as jsonwrite
except:
	try:
		from json import write as jsonwrite
	except:
		print >>sys.stderr, "No known json library installed. Plain Python printing."
		jsonwrite = None


def find_parent( dirpath, subleaf, get_realpath=False ):
	if get_realpath:
		dirpath = realpath( dirpath )
	dirparts = dirpath.split( os.sep )
	while dirparts:
		path = join( *dirparts )
		if isdir( join( *tuple( dirparts )+( subleaf, ) ) ):
			return path
		dirparts.pop()

def find_volume( dirpath ):
	vol = find_parent( dirpath, '.volume' )
	if not vol:
		vol = find_parent( dirpath, '.volume', True )
	if vol:
		print "In volume %r" % vol
		vol = join( vol, '.volume' )
	else:
		vol = expanduser( '~/.treemap/' ) # XXX: *nix only
		if not exists( vol ):
			os.makedirs( vol )
		print "No volumes, treemap storage at %r" % vol
	return vol


class FSWrapper:
	def __init__( self, path ):
		self.init( path )
	def init( self, path ):
		path = path.rstrip( os.sep )
		self._path = path
		self.dirname = dirname( path )
		self.basename = basename( path )
		self.isdir = isdir( path )
		self.islink = islink( path )
		self.isother = not self.isdir and \
				not self.islink and not isfile( path )
	@property 
	def path( self ):
		if self.isdir:
			return self._path + os.sep
	@property 
	def name( self ):
		n = self.basename
		if self.isdir:
			n += os.sep
		return n
	def exists( self ):
		return exists( self.path )
	def yield_all( self ):
		"Yield all nodes on the way to path. "
		parts = self._path.split( os.sep )
		while parts:
			p = join( parts )
			yield p
			parts.pop()
	def find_all( self ):
		"Yield any nodes on the way to root. "
		parts = self._path.split( os.sep )
		while parts:
			p = join( *parts )
			if p and exists( p ):
				yield p
			parts.pop()


class Treemap:

	"""
	Encapsulates current Treemap implementation. 
	Works on a volume tree (one with metadir) and populates tree.
	"""

	@classmethod
	def init( Klass, treemapdir ):
		if exists( treemapdir ):
			Klass.storage = shelve.open( join( treemapdir, 'treemap.db' ) )
		else:
			print >>sys.stderr, "Missing treemapdir %s" % treemapdir

	def __init__( self, path ):
		self.__class__.init( path )
		self.load( path )

	def load( self, path ):
		self.fs = FSWrapper( path )
	def __del__( self ):
		pass
	def __getstate__( self ):
		return ( self.fs._path, self.data )
	def __setstate__( self, *state ):
		path, self.data = state
		self.load( path )
	def walk_path( self, path ):
		pass	
	def init_path( self ):
		for p in self.fs.yield_all():
			pass
	def exists( self, path, opts ):
		"Return data at path. "
		return path in self.storage
	def fetch( self, path, opts ):
		"Return data at path. "
		return self.storage[ path ]
	def store( self, opts ):
		"Store data at path, marking any node up as dirty. "
		parent_path = self.find( )
		if not parent_path:
			self.init_path( )
		else:
			for parent in self.find_all( ):
				self.invalidate( parent )
		self.storage[ path ] = data
	def invalidate( self, path ):
		data = self.fetch( path )
		#if data
		self.store( self, path, data )
	def find( self ):
		"Return the next node up, if any. "
		for p in self.find_all( ):
			return p
	def find_all( self ):
		for p in self.fs.find_all( ):
			yield self.fetch( p )


class Node(dict):
	"""
	Interface on top of normal dictionary to work easily with tree nodes
	which can have a name, attributes, and a value list.
	"""
	def __init__( self, name ):
		self[ name ] = None

	def getname(self):
		for key in self:
			if not key.startswith('@'):
				return key

	def setname( self, name ):
		oldname = self.getname()
		val = self[ oldname ]
		del self[ oldname ]
		self[ name ] = val
	name = property( getname, setname )
	"Node.name is a property or '@'-prefix attribute name. "
	def append( self, val ):
		"Node().value append"
		if not isinstance( self.value, list ):
			self[ self.name ] = []
		self.value.append( val )

	def remove( self, val ):
		"self item remove"
		self[ self.name ].remove( val )

	def getvalue( self ):
		"self item return"
		return self[ self.name ]
	value = property( getvalue )
	"Node.value is a list of subnode instances. "

	def getattrs( self ):
		attrs = {}
		for key in self:
			if key.startswith( '@' ):
				attrs[ key[ 1: ] ] = self[ key ]
		return attrs

	attributes = property( getattrs )

	def __getattr__( self, name ):
		#print super( Node, self ).__dict__.keys()
		# @xxx: won't properties show up in __dict__?
		if name in self.__dict__ or name in ( 'name', 'value', 'attributes' ):
			return super( Node, self ).__getattr__( name )
		elif '@' + name in self:
			return self[ '@' + name ]

	def __setattr__( self, name, value ):
		if name in self.__dict__ or name in ( 'name', 'value', 'attributes' ):
			super( Node, self ).__setattr__( name, value )
		else:
			self[ '@' + name ] = value

	def space( self, parent_path ):
		"""
		Return the size in disk blocks taken by the filetree.
		"""
		path = join( parent_path, self.name )
		if self.value:
			space = 0
			for node in self.value:
				space += node.space( path )
			return space
		elif islink( path ):
			return lstat( path ).st_blocks
		elif exists( path ):
			return stat( path ).st_blocks
		else:
			raise Exception( "Path does not exist: %s" % path )

	def size( self, parent_path ):
		"""
		Return the size in bytes taken by the files in the filetree.
		XXX: does this count dirs?
		"""
		path = join( parent_path, self.name )
		if self.value:
			size = 0
			for node in self.value:
				size += node.size( path )
			return size 
		elif islink( path ):
			return lstat( path ).st_size
		elif exists( path ):
			return stat( path ).st_size
		else:
			raise Exception( "Path does not exist: %s" % path )

	@property
	def isdir( self ):
		"Check for trailing '/' convention. "
		return self.name.endswith( os.sep )

	def files( self, parent_path ):
		"This does a recursive file count. "
		path = join( parent_path, self.name )
		if self.value:
			files = 0
			for node in self.value:
				files += node.files( path )
			return files
		else:
			return 1

	@classmethod
	def tree( Klass, path, opts ):
		"""
		Return a tree of Klass instances for each subpath.
		"""
		node = Klass( basename( path ) + ( isdir( path ) and os.sep or '' ) )
		if isdir( path ):
			for fn in listdir( path ):
				# Be liberal... take a look at non decoded stuff
				if not isinstance( fn, unicode ):
					# try decode with default codec
					try:
						fn = fn.decode( opts.fs_encoding )
					except UnicodeDecodeError:
						print >>sys.stderr, "unable to decode:", path, fn
						continue
				subpath = join( path, fn )
				node.append( Node.tree( subpath, opts ) )
		return node

	# Persistence methods
	# XXX: unused iface stubs here, see dev_treemap_tmp

	def reload_data( self, parentdir, force_clean=None ):
		"""
		Call this after initialization to compare the values to the 
		DB, and set the 'fresh' attribute.
		"""

	def commit( self, parentdir ):
		"""
		Call this after running?
		Need to clean up non existant paths
		"""

	# Static interface to shelved dictionaries

	storage = None

	@classmethod
	def set_stored( clss, path, node ):
		clss.storage[ path.encode() ] = node

	@classmethod
	def is_stored( clss, path ):
		return path.encode() in clss.storage

	@classmethod
	def get_stored( clss, path ):
		return clss.storage[ path.encode() ]

	# /XXX end of dev_treemap_tmp iface

def usage(msg=0):
	print """%s
Usage:
	%% treemap.py [opts] directory

Opts:
	-d, --debug		Plain Python printing with total space data.

	""" % sys.modules[__name__].__doc__
	if msg:
		msg = 'error: '+msg
	sys.exit(msg)

def main():
	# Script args
	import confparse
	opts = confparse.Values(dict(
			fs_encoding = sys.getfilesystemencoding(),
			voldir = None,
			debug = None,
		))
	argv = list(sys.argv)

	opts.treepath = argv.pop()
	# strip trailing os.sep
	if not basename(opts.treepath): 
		opts.treepath = opts.treepath[:-1]
	assert basename(opts.treepath) and isdir(opts.treepath), \
			usage("Must have dir as last argument")
	path = opts.treepath

	opts.debug = ( '-d' in argv and argv.remove( '-d' ) ) or (
			'--debug' in argv and argv.remove( '--debug' ) )

	# Configure
	if not opts.voldir:
		opts.voldir = find_volume( path )

	treemap = Treemap( opts.voldir )	

	# Get existing treemap or create new
	tree = treemap.find( )
	#print 'Found tree', tree
	if not tree: 
		tree = Node.tree( path, opts )
		#print 'New tree', tree

#	treemap.store( path, tree, opts )

	blocks = tree.space( dirname( path ) )

	fstree_root_report()
	fstree_report( opts.debug, tree, treemap )

def fstree_root_report():
	st = os.statvfs( '/' )
	free = st.f_bavail * st.f_frsize
	total = st.f_blocks * st.f_frsize
	used = (st.f_blocks - st.f_bfree) * st.f_frsize
#	print 'reported'
#	print '%s free\n%s total\n%s used' % (free,total,used)
#	print round( free / 1024.0 ** 3, 1 ), 'GB free'
#	print round( used / 1024.0 ** 3, 1 ), 'GB used'
#	print round( total / 1024.0 ** 3, 1 ), 'GB total'

	free_gb_rounded = int( round( free / 1024 ** 3 ) )
	disk_usage = int( round( ( used * 100.0 ) / total ) )
	print "%s GB available (%s%% disk usage)" % ( free_gb_rounded, disk_usage )

def fstree_report( debug, tree, treemap ):
	if jsonwrite and not debug:
		pass #print jsonwrite( tree )
	else:
		#print pformat( tree )
		print treemap.fs._path
		total = float( tree.size( dirname( treemap.fs._path ) ) )
		used = float( tree.space( dirname( treemap.fs._path ) ) )
		files = float( tree.files( dirname( treemap.fs._path ) ) )
		print "%s mtime" % os.path.getmtime( treemap.fs._path )
		print 'Tree size:'
		print total, 'bytes', files, 'files'
		print 'Used space:'
		print used, 'B'
		print used/1024, 'KB'
		print used/1024**2, 'MB'
		print used/1024**3, 'GB'
		print "%s blocks\n%s bytes on disk" % ( used, used * 512 )



if __name__ == '__main__':

	main()


