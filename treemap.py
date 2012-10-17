#!/usr/bin/env python
"""tree - Creates a tree of a filesystem hierarchy.

Calculates cumulative space of each directory. Output in JSON format.

Copyleft, May 2007.  B. van Berkum <berend `at` dotmpe `dot` com>

Updates
-------
Oktober 2012
	- using blksize to calculate actual occupied disk space.
	- a too detailed storage will drag performance. The current operations
	  per file are constant, so file count is the limiting factor.

TODO: the torage should create a report for some directory, sorry aout
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

import sys
import os
import shelve
from pprint import pformat
from os import listdir, stat, lstat
from os.path import join, exists, islink, isdir, getsize, basename, dirname, expanduser
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


def find_parent( dirpath, subleaf, realpath=False ):
	if realpath:
		dirpath = os.path.realpath( dirpath )
	dirparts = dirpath.split( '/' )
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
		vol = expanduser( '~/.treemap' )
		if not exists( vol ):
			os.makedirs( vol )
		print "No volumes, storage at %r" % vol
	return vol


class FSWrapper:
	def __init__( self, path ):
		self.init( path )
	def init( self, path ):
		path = path.rstrip( os.sep )
		self._path = path
		self.dirname = os.path.dirname( path )
		self.basename = os.path.basename( path )
		self.isdir = os.path.isdir( path )
		self.islink = os.path.islink( path )
		self.isother = not self.isdir and \
				not self.islink and not os.path.isfile( path )
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
		return os.path.exists( self.path )
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
			p = join( parts )
			if p and self.exists( p ):
				yield p
			parts.pop()

		

class Treemap:

	@staticmethod
	def init( treemapdir ):
		self.storage = shelve.open( join( treemapdir, 'treemap.db' ) )

	def __init__( self, path ):
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
	def find_all( self, path ):
		for p in self.fs.find_all( ):
			yield self.fetch( p )

class Node(dict):
	"""Interface on top of normal dictionary to work easily with tree nodes
	which can have a name, attributes, and a value list.
	"""
	def __init__(self, name):
		self[name] = None

	def getname(self):
		for key in self:
			if not key.startswith('@'):
				return key

	def setname(self, name):
		oldname = self.getname()
		val = self[oldname]
		del self[oldname]
		self[name] = val

	name = property(getname, setname)

	def append(self, val):
		if not isinstance(self.value, list):
			self[self.name] = []
		self.value.append(val)

	def getvalue(self):
		return self[self.name]

	value = property(getvalue)

	def getattrs(self):
		attrs = {}
		for key in self:
			if key.startswith('@'):
				attrs[key[1:]] = self[key]
		return attrs

	attributes = property(getattrs)

	def __getattr__(self, name):
		# @xxx: won't properties show up in __dict__?
		if name in self.__dict__ or name in ('name', 'value', 'attributes'):
			return super(Node, self).__getattr__(name)
		elif '@'+name in self:
			return self['@'+name]

	def __setattr__(self, name, value):
		if name in self.__dict__ or name in ('name', 'value', 'attributes'):
			super(Node, self).__setattr__(name, value)
		else:
			self['@'+name] = value

	def space( self, parent_path ):
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
		return self.name.endswith( os.sep )

	def files( self, parent_path ):
		path = join( parent_path, self.name )
		if self.value:
			files = 0
			for node in self.value:
				files += node.files( path )
			return files
		else:
			return 1

	@classmethod
	def tree( clss, path, opts ):
		node = clss( basename( path ) + ( isdir( path ) and os.sep or '' ) )
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


def fs_treesize(root, tree, files_as_nodes=True):
	"""Add 'space' attributes to all nodes.

	Root is the path on which the tree is rooted.

	Tree is a dict representing a node in the filesystem hierarchy.

	Size is cumulative for each folder. The space attribute indicates
	used disk space, while the size indicates actual bytesize of the contents.
	"""
	if not root:
		root = './'
	assert root and isinstance( root, basestring ), root
	assert isdir( root ), stat( root )
	assert isinstance( tree, Node )
	# XXX: os.stat().st_blksize contains the OS preferred blocksize, usually 4k, 
	# st_blocks reports the actual number of 512byte blocks that are used, so on
	# a system with 4k blocks, it reports a minimum of 8 blocks.
	cdir = join( root, tree.name )

	if not tree.space:
		size = 0
		space = 0
		if tree.value:
			tree.count = len(tree.value)
			for node in tree.value: # for each node in this dir:
				path = join( cdir, node.name )
				if isdir( path ):
					# subdir, recurse and add space
					fs_treesize( cdir, node )
					tree.count += node.count
					space += node.space
					size += node.size
				else:
					# filename, add sizes
					actual_size = 0
					used_space = 0
					try:
						actual_size = getsize( path )
					except Exception, e:
						print >>sys.stderr, "could not get size of %s: %s" % ( path, e )
					try:
						used_space = lstat( path ).st_blocks * 512
					except Exception, e:
						print >>sys.stderr, "could not stat %s: %s" % ( path, e )
					node.size = actual_size
					node.space = used_space
					size += actual_size
					space += used_space
		else:
			tree.count = 0
		tree.size = size
		tree.space = space
	tree.space += ( stat( cdir ).st_blocks * 512 )


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

	# Walk filesystem, updating where needed
	treemap.report( path )

	# Walk filesystem, updating where needed
	tree = Node.load( path )
	print tree.size

	treemap.reports.append( )

	# Add space attributes
	fs_treesize( dirname(path), tree )

	# Set proper root path
	tree.name = path

	### Output
	if jsonwrite and not debug:
		print jsonwrite( tree )
	else:
		#print tree
		total = float( tree.size )
		used = float( tree.space )
		print 'Tree size:'
		print tree.size, 'bytes', tree.count, 'items'
		print 'Used space:'
		print tree.space, 'B'
		print used/1024, 'KB'
		print used/1024**2, 'MB'
		print used/1024**3, 'GB'

if __name__ == '__main__':

	# Script args
	import confparse
	opts = confparse.Values(dict(
			fs_encoding = sys.getfilesystemencoding(),
			voldir = None,
			debug = None,
		))
	argv = list(sys.argv)

	opts.path = argv.pop()
	# strip trailing os.sep
	if not basename(opts.path): 
		opts.path = opts.path[:-1]
	assert basename(os.path) and isdir(os.path), \
			usage("Must have dir as last argument")

	opts.debug = ( '-d' in argv and argv.remove( '-d' ) ) or (
			'--debug' in argv and argv.remove( '--debug' ) )

	# Configure
	if not opts.voldir:
		opts.voldir = find_volume( path )

	treemap = Treemap( treemap_dir )	

	# Start
	tree = treemap.find( path, opts )
	if not tree: 
		tree = Node.tree( path, opts )

#	treemap.store( path, tree, opts )

#	print pformat( tree )
	blocks = tree.space( dirname( path ) )

	print '\\','-'*32, path
	print "%s mtime" % os.path.getmtime( path )
	print "%s blocks\n%s bytes on disk" % ( blocks, blocks * 512 )
	print '%s bytes in files\n%s files' % ( 
			tree.size( dirname( path ) ), 
			tree.files( dirname( path ) )
		)
	print '/','-'*32, path

#	print '-'*79, '/'
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

