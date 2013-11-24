#!/usr/bin/env python
"""tree - Creates a tree of a filesystem hierarchy.

Calculates cumulative size of each directory. Output in JSON format.

Copyleft, May 2007.  B. van Berkum <berend `at` dotmpe `dot` com>
"""
import sys
from os import listdir
from os.path import join, isdir, getsize, basename, dirname
try:
	# @bvb: simplejson thinks it should be different and deprecated read() and write()
	# not sure why... @xxx: simplejson has UTF-8 default, json uses ASCII I think?
	from simplejson import dumps as jsonwrite
except:
	try:
		from ujson import dumps as jsonwrite
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
	"""Add 'size' attributes to all nodes.

	Root is the path on which the tree is rooted.

	Tree is a dict representing a node in the filesystem hierarchy.

	Size is cumulative.
	"""
	assert isinstance(root, basestring) and isdir(root)
	assert isinstance(tree, Node)

	if not tree.size:
		dir = join(root, tree.name)
		size = 0
		if tree.value:
			for node in tree.value: # for each node in this dir:
				path = join(dir, node.name)
				if isdir(path):
					# subdir, recurse and add size
					fs_treesize(dir, node)
					size += node.size
				else:
					# filename, add size
					try:
						csize = getsize(path)
						node.size = csize
						size += csize
					except:
						print >>sys.stderr, "could not get size of %s" % path
		tree.size = size

def usage(msg=0):
	print """%s
Usage:
	%% treemap.py [opts] directory

Opts:
	-d, --debug		Plain Python printing with total size data.
	-json           Write tree as JSON.
	-jsonxml        Transform tree to more XML like container hierarchy befor writing as JSON.

	""" % sys.modules[__name__].__doc__
	if msg:
		msg = 'error: '+msg
	sys.exit(msg)

def translate_xml_nesting(tree):
	newtree = {'children':[]}
	for k in tree:
		v = tree[k]
		if k.startswith('@'):
			if v:
				assert isinstance(v, (int,float,basestring)), v
			assert k.startswith('@'), k
			newtree[k[1:]] = v
		else:
			assert not v or isinstance(v, list), v
			newtree['name'] = k
			if v:
				for subnode in v:
					newtree['children'].append( translate_xml_nesting(subnode) )
	assert 'name' in newtree and newtree['name'], newtree
	if not newtree['children']:
		del newtree['children']
	return newtree

if __name__ == '__main__':
	# Script args
	path = sys.argv.pop()
	if not basename(path):
		path = path[:-1]
	assert basename(path) and isdir(path), usage("Must have dir as last argument")

	debug = None
	if '-d' in sys.argv or '--debug' in sys.argv:
		print >>sys.stderr, "Debugmode"
		debug = True
	json = None
	if '-j' in sys.argv or '--json' in sys.argv:
		json = True
	jsonxml = None
	if '-J' in sys.argv or '--jsonxml' in sys.argv:
		jsonxml = True

	# Walk filesystem
	tree = fs_tree(path)

	# Add size attributes
	fs_treesize(dirname(path), tree)

	# Set proper root path
	tree.name = path

	### Output
	if jsonwrite and ( json and not debug ):
		print jsonwrite(tree)

	elif jsonwrite and ( jsonxml and not debug ):
		tree = translate_xml_nesting(tree)
		print jsonwrite(tree)

	else:
		print >>sys.stderr, 'No JSON.'
		print tree
		total = float(tree.size)
		print 'Tree size:'
		print total, 'B'
		print total/1024, 'KB'
		print total/1024**2, 'MB'
		print total/1024**3, 'GB'

