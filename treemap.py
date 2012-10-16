#!/usr/bin/env python
"""tree - Creates a tree of a filesystem hierarchy.

Calculates cumulative space of each directory. Output in JSON format.

Copyleft, May 2007.  B. van Berkum <berend `at` dotmpe `dot` com>

Updates
-------
Oktober 2012
	- using blksize to calculate actual occupied disk space.
"""
import sys
from os import listdir, stat, lstat
from os.path import join, isdir, getsize, basename, dirname
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

	def __repr__(self):
		return "<%s%s%s>" % (self.name, self.attributes, self.value or '')


def fs_tree(dir):
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
	dirname = basename(dir)
	tree = Node(dirname)
	for fn in listdir(dir):
		# Be liberal... take a look at non decoded stuff
		if not isinstance(fn, unicode):
			# try decode with default codec
			try:
				fn = fn.decode(enc)
			except UnicodeDecodeError:
				print >>sys.stderr, "corrupt path:", dir, fn
				continue
		# normal ops
		path = join(dir, fn)
		if isdir(path):
			# Recurse
			tree.append(fs_tree(path))
		else:
			tree.append(Node(fn))

	return tree


def fs_treesize(root, tree, files_as_nodes=True):
	"""Add 'space' attributes to all nodes.

	Root is the path on which the tree is rooted.

	Tree is a dict representing a node in the filesystem hierarchy.

	Size is cumulative for each folder.
	"""
	if not root:
		root = './'
	assert root and isinstance(root, basestring), root
	assert isdir(root), stat(root)
	assert isinstance(tree, Node)
	# XXX: os.stat().st_blksize contains the OS preferred blocksize, usually 4k, 
	# st_blocks reports the actual number of 512byte blocks that are used, so on
	# a system with 4k blocks, it reports a minimum of 8 blocks.

	if not tree.space:
		cdir = join(root, tree.name)
		size = 0
		space = 0
		if tree.value:
			for node in tree.value: # for each node in this dir:
				path = join(cdir, node.name)
				if isdir(path):
					# subdir, recurse and add space
					fs_treesize(cdir, node)
					space += node.space + (stat(path).st_blocks * 512)
				else:
					# filename, add sizes
					actual_size = 0
					used_space = 0
					try:
						actual_size = getsize(path)
					except Exception, e:
						print >>sys.stderr, "could not get size of %s: %s" % (path, e)
					try:
						used_space = lstat(path).st_blocks * 512
					except Exception, e:
						print >>sys.stderr, "could not stat %s: %s" % (path, e)
					node.size = actual_size
					node.space = used_space
					size += actual_size
					space += used_space
		tree.size = size
		tree.space = space


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


if __name__ == '__main__':
	# Script args
	path = sys.argv.pop()
	if not basename(path):
		path = path[:-1]
	assert basename(path) and isdir(path), usage("Must have dir as last argument")

	debug = None
	if '-d' in sys.argv or '--debug' in sys.argv:
		debug = True

	# Walk filesystem
	tree = fs_tree(path)

	# Add space attributes
	fs_treesize(dirname(path), tree)

	# Set proper root path
	tree.name = path

	### Output
	if jsonwrite and not debug:
		print jsonwrite(tree)
	else:
		#print tree
		total = float(tree.space)
		used = float(tree.space)
		print 'Used space:'
		print used, 'B'
		print used/1024, 'KB'
		print used/1024**2, 'MB'
		print used/1024**3, 'GB'



