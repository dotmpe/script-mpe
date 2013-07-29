"""
res - Read metadata from metafiles.

Classes to represent a file or cluster of files from which specific metadata
may be derived. The objective is using this as a toolkit, to integrate into
programs that work on metadata and/or (media) files.

TODO:
- Persist composite objects:
- Metalink reader/adapter. Metalink4 <-> HTTPResponseHeaders
- Content-* properties
"""
import os
import uuid
import anydbm
import shelve

from script_mpe import confparse
#from script_mpe import lib
#from script_mpe from taxus import get_session
from script_mpe import log

import iface
import util
from persistence import PersistedMetaObject
from fs import File, Dir
from mime import MIMEHeader
from metafile import Metafile, Metadir, Meta



"""

Registry
	handler class
		handler name -> 
	
	Volume
		rsr:sha1sum
		rsr:sprssum

	Mediafile
		rsr:metafile
		txs:volume
		txs:workspace

"""


class Workspace(Metadir):

	"""
	A workspace offers and interface to several indices located in the dotdir.
	"""

	dotdir = 'cllct'

	index_specs = [
		]

	def __init__(self, path):
		super(Workspace, self).__init__(path)
		self.__id = None
		self.store = None
		self.indices = {}
		if self.exists():
			self.init()

	@property
	def guid(self):
		if self.exists():
			return open(self.id_path).read().strip()
		return ''

	def exists(self):
		return os.path.exists(self.id_path)

	def init(self, create=False, reset=False):
		"""
		"""
		if self.exists() and not reset:
			self.__id = open(self.id_path).read().strip()
		elif reset or create:
			self.__id = str(uuid.uuid4())
			if not os.path.exists(self.full_path):
				os.mkdir(self.full_path)
			open(self.id_path, 'w+').write(self.__id)
			print reset and 'Reset' or 'Created', self
		else:
			assert False # XXX: cannot manage dotdir
		self.store = self.init_store(reset) # store shared with Metafile.
		self.indices = self.init_indices(reset)

	@property
	def dbref(self):
		return self.idxref(self.dotdir_id, 'shelve')

	def init_store(self, truncate=False): 
		assert not truncate
		return PersistedMetaObject.get_store(name=Metafile.storage_name, dbref=self.dbref)
		#return PersistedMetaObject.get_store(name=self.dotdir, dbref=self.dbref, ro=rw)

	def idxref(self, name, type='db'):
		return os.path.join(self.full_path, '%s.%s' % (name, type))
		
	def init_indices(self, truncate=False):
		flag = truncate and 'n' or 'c'
		idcs = {}
		for name in self.__class__.index_specs:
			ref = self.idxref(name)
			if ref.endswith('.db'):
				idx = anydbm.open(ref, flag)
			elif ref.endswith('.shelve'):
				idx = shelve.open(ref, flag)
			idcs[name] = idx
		return confparse.Values(idcs)


class Volume(Workspace):

	dotdir_id = 'volume'

	index_specs = [
				'sparsesum',
				'sha1sum',
				'dirs'
			]

	def pathname(self, name, basedir=None):
		if basedir and basedir.startswith(self.path):
			path = basedir[len(self.path.rstrip('/'))+1:]
		else:
			path = ""
		return os.path.join(path, name)


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


