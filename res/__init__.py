"""
Read metadata from metafiles.

- Persist composite objects
- Metalink4 <-> HTTPResponseHeaders

- Content-*

"""
import os
import uuid
import shelve

import iface
#import lib
import confparse
#from taxus import get_session
import log

import util
from persistence import PersistedMetaObject
from fs import File, Dir
from mime import MIMEHeader
from metafile import Metafile



class SHA1Sum(object):
	checksums = None
	def __init__(self):
		self.checksums = {}
	def parse_data(self, lines):
		for line in lines:
			p = line.find(' ')
			checksum, filepath = line[:p].strip(), line[p+1:].strip()
			self.checksums[checksum] = filepath
	def __iter__(self):
		return iter(self.checksums)
	def __getitem__(self, checksum):
		return self.checksums[checksum]


class Workspace(object):

	dotdir = 'cllct'
	dotdir_id = 'workspace'

	def __init__(self, path):
		self.path = path
		assert not path.endswith(self.dotdir)
		assert not path.endswith(self.dotdir+'/')
		self.init()

	def init(self, create=False):
		if create:
			print 'Creating', self
			self.__id = str(uuid.uuid4())
			if not os.path.exists(self.full_path):
				os.mkdir(self.full_path)
			open(self.id_path, 'w+').write(self.__id)
			self.db
		elif os.path.exists(self.id_path):
			self.__id = open(self.id_path).read().strip()

	@property
	def id_path(self):
		return os.path.join(self.full_path, self.dotdir_id)

	@property
	def full_path(self):
		return os.path.join(self.path, '.'+self.dotdir)

	def __str__(self):
		return repr(self)

	def __repr__(self):
		return "<%s %s at %s>" % (util.cn(self), hex(id(self)), self.id_path)

	@classmethod
	def find(clss, *paths):
		path = None
		for path in confparse.find_config_path(clss.dotdir, paths=list(paths)):
			vid = os.path.join(path, clss.dotdir_id)
			if os.path.exists(vid):
				break
			else:
				path = None
		if path:
			return Volume(os.path.dirname(path))

	@property
	def db(self):
		dbname = os.path.join(self.full_path, '%s.shelve' % self.dotdir_id)
		return shelve.open(dbname, 'c')


class Volume(Workspace):

	dotdir_id = 'volume'


class Repo(object):

	repo_match = (
			".git",
			".svn"
		)

	@classmethod
	def is_repo(klass, path):
		for n in klass.repo_match:
			if os.path.exists(os.path.join(path, n)):
				return True

	@classmethod
	def walk(klass, path, bare=False, max_depth=-1):
		# XXX: may rewrite to Dir.walk
		"""
		Walk all files that may have a metafile, and notice any metafile(-like)
		neighbors.
		"""
		assert not bare, 'TODO'
		for root, nodes, leafs in os.walk(path):
			for node in list(nodes):
				dirpath = os.path.join(root, node)
				if not os.path.exists(dirpath):
					log.err("Error: reported non existant node %s", dirpath)
					nodes.remove(node)
					continue
				depth = dirpath.replace(path,'').strip('/').count('/')
				if Dir.ignored(dirpath):
					log.err("Ignored directory %r", dirpath)
					nodes.remove(node)
					continue
				elif max_depth != -1:
					if depth >= max_depth:
						nodes.remove(node)
						continue
				if klass.is_repo(dirpath):
					nodes.remove(node)
					yield dirpath


