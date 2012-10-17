#!/usr/bin/env python
"""tree - Creates a tree of a filesystem hierarchy.

Calculates cumulative space of each directory. Output in JSON format.

Copyleft, May 2007.  B. van Berkum <berend `at` dotmpe `dot` com>

Updates
-------
Oktober 2012
	- using blksize to calculate actual occupied disk space.
	- adding storage::

	         path@value
	         path@space
	         path@size
"""
import sys
import os
import shelve
from types import NoneType
from pprint import pformat
from os import listdir, stat, lstat
from os.path import join, exists, isdir, getsize, basename, dirname, expanduser
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
		print "No volumes, treemap store at %r" % vol
	return vol


class Node(dict):
	"""
	Interface on top of normal dictionary to work easily with tree nodes
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

	name = property( getname, setname )

	"Node.value is a list of subnode instances. "

	def append( self, val ):
		if not isinstance( self.value, list ):
			self[ self.name ] = []
		self.value.append( val )

	def remove( self, val ):
		self[ self.name ].remove( val )

	def getvalue( self ):
		return self[ self.name ]

	value = property( getvalue )

	def getattrs( self ):
		attrs = {}
		for key in self:
			if key.startswith( '@' ):
				attrs[ key[ 1: ] ] = self[ key ]
		return attrs

	attributes = property( getattrs )

	def __getattr__( self, name ):
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

#	def __repr__(self):
#		return "<%s%s%s>" % ( self.name, self.attributes, self.value or '' )

	# Persistence methods

	def reload_data( self, parentdir, force_clean=None ):
		"""
		Call this after initialization to compare the values to the 
		DB, and set the 'fresh' attribute.
		"""
#		print 'reload', '-'*79, parentdir, self.name
		path = join( parentdir, self.name )
		clss = self.__class__
		if clss.is_stored( path ):
			data = clss.get_stored( path )
			# XXX: this is only needed for the rootnode which has a pull path
			assert os.sep not in self.__dict__, self.__dict__
			if path in data:
				data[ self.name ] = data[ path ]
				del data[ path ]
			# /XXX
			self.update( data )
#			print '+' * 79
#			print self.name, self.value
			if force_clean != None:
				self.fresh = force_clean
			elif os.path.exists( path ):
				cur_mtime = os.path.getmtime( path )
				self.fresh = self.mtime == cur_mtime
				if not self.fresh:
					self.mtime = cur_mtime
			if self.value:
				assert os.sep not in self.value
				newvalue = []
				for subnode_name in self.value:
					node_path = join( path, subnode_name )
					# FIXME: should fs_node_init here
					subnode = fs_node_init( node_path )
					assert os.sep != subnode.name, subnode.name
					if force_clean != None or self.fresh:
						# assert os.path.exists
						subnode.reload_data( path, self.fresh )
					elif os.path.exists( node_path ):
						subnode.reload_data( path )
					newvalue.append( subnode ) # XXX: where to handle deletion
				self[ self.name ] = newvalue
#			print self.name, self.value
#		print '/reload', '-'*79, parentdir, self.name

	def commit( self, parentdir ):
		"""
		Call this after running?
		Need to clean up non existant paths
		"""
#		print 'commit', '-'*79, parentdir, self.name
		clss = self.__class__
		path = join( parentdir, self.name )
		data = self.copy()
		if '@fresh' in data:
			del data['@fresh']
		#or raise Exception( "Missing attr for %s" % path )
		assert os.sep not in data, data
		if data[ self.name ]:
			data[ self.name ] = [ subnode.name for subnode in self.value ]
			[ subnode.commit( path ) for subnode in self.value ]
		assert os.sep not in data, data
		clss.set_stored( path, data )

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


def fs_node_init( path ):
#	print '\fs_node_init', '-'*79, path
	path = path.rstrip( os.sep )
	path2 = path
	if isdir( path ) and path[ -1 ] != os.sep:
		path2 += os.sep
	node = Node( basename( path ) + ( isdir( path ) and os.sep or '' ) )
	if Node.is_stored( path2 ):
		node.reload_data( dirname( path ) )
		return node
	else:
		return Node( basename( path ) + ( isdir( path ) and os.sep or '' ) )
#	print '/fs_node_init', '-'*79, path


def fs_tree( dirpath, tree ):
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
	enc = sys.getfilesystemencoding()
	path = join( dirpath, tree.name )
#	print '\\fs_tree', '-'*79, dirpath, tree.name
#	print isdir( path ), tree.fresh
	if isdir( path ) and not tree.fresh:
		update = {}
		if tree.value:
			for subnode in tree.value:
				if not exists( join( path, subnode.name ) ):
					tree.remove( subnode )
				else:
					update[ subnode.name ] = subnode
		for fn in listdir( path ):
			# Be liberal... take a look at non decoded stuff
			if not isinstance( fn, unicode ):
				# try decode with default codec
				try:
					fn = fn.decode( enc )
				except UnicodeDecodeError:
					print >>sys.stderr, "unable to decode:", path, fn
					continue
			subpath = join( path, fn )
			if isdir( subpath ):
				fn += os.sep
#				print '\============',path, fn
			if fn in update:
				subnode = update[ fn ]
			else:
				subnode = fs_node_init( subpath )
				tree.append( subnode )
			fs_tree( path, subnode )
#			if isdir( subpath ):
#				print '/============',path, fn
#	print '/fs_tree', '-'*79, dirpath, tree.name


def fs_treesize( root, tree, files_as_nodes=True ):
	"""Add 'space' attributes to all nodes.

	Root is the path on which the tree is rooted.

	Tree is a dict representing a node in the filesystem hierarchy.

	Size is cumulative for each folder. The space attribute indicates
	used disk space, while the size indicates actual bytesize of the contents.
	"""
	if not root:
		root = '.' + os.sep
	assert root and isinstance( root, basestring ), root
	assert isdir( root ), stat( root )
	assert isinstance( tree, Node )
	# XXX: os.stat().st_blksize contains the OS preferred blocksize, usually 4k, 
	# st_blocks reports the actual number of 512byte blocks that are used, so on
	# a system with 4k blocks, it reports a minimum of 8 blocks.
	cdir = join( root, tree.name )
	if not tree.fresh or not tree.space or not tree.size:
		size = 0
		space = 0
		if tree.value:
			tree.count = len(tree.value)
			for node in tree.value: # for each node in this dir:
				path = join( cdir, node.name )
				if not exists( path ):
					continue
					raise Exception( path )
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

def fs_treemap_write( debug, tree ):
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


def main():
	# Script args
	path = sys.argv.pop()
	if not basename(path):
		path = path[:-1]
	assert basename(path) and isdir(path), usage("Must have dir as last argument")

	debug = None
	if '-d' in sys.argv or '--debug' in sys.argv:
		debug = True

	# Get wrapper facade
	
	# Get shelve for storage
	treemap_dir = find_volume( path )
	storage = Node.storage = shelve.open( join( treemap_dir, 'treemap.db' ) )

	# Walk filesystem, updating where needed
	tree = fs_node_init( path )
	fs_tree( dirname( path ), tree )
	print 'fs_tree', pformat(tree)

	# Add space attributes
#	fs_treesize( dirname( path ), tree )

	# Set proper root path, and output
	tree.name = path + os.sep
#	fs_treemap_write( debug, tree )
	#print 'fs_treemap_write', pformat(tree)

	# Update storage
	tree.commit( dirname( path ) )
#	print storage[ path + os.sep ]
#	for fn in listdir( path ):
#		sub = join( path, fn )
#		if isdir( sub ):
#			sub += os.sep
#		print storage[ sub ]
	storage.close()

if __name__ == '__main__':

	main()

