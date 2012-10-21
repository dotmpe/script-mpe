import os
import confparse
from persistence import PersistedMetaObject

import log


class Workspace(PersistedMetaObject):

	def __init__(self, path):
		self.name = os.path.basename(path)
		self.path = os.path.dirname(path)

	@property
	def full_path(self):
		return os.path.join(self.path, self.name)

	def __str__(self):
		return "[%s %s %s]" % (self.__class__.__name__, self.path, self.name)

	def key(self):
		return self.name


class Volume(PersistedMetaObject):

	"""
	Container for metafiles.
	"""

	indices = (
#			'inode',
#			'sha1_content_digest',
#			'md5_content_digest',
#			'pwd',
			( 'vpath', 'objects' ),
			( 'vtype', 'index' ),
		)

	@classmethod
	def get_indices(Klass, self):
		return Klass.indices + PersistedMetaObject.get_indices()

#	def path(self, path):
#		self.name = os.path.basename(path)
#		self.path = os.path.dirname(path)
#	def __str__(self):
#		return repr(self)
#	def __repr__(self):
#		return "<Volume 0x%x at %s>" % (hash(self), self.db)
#	@property
#	def db(self):
#		return os.path.join(self.full_path, 'volume.db')

	@classmethod
	def find_root(Klass, dirpath, opts=None, conf=None):
		"""
		"""
		assert conf, conf
		paths = list(confparse.find_config_path(conf.cmd.lib.name, 
				path=dirpath, prefixes=['.']))
		if not paths:
			return
		path = paths[0]
		log.note( 'Found volumedir <%s> for dirpath <%s>' %( path, dirpath ) )
		return path
		
	@classmethod
	def new(Klass, dirpath, lib, settings):
		"""
		XXX: remove, should be in PersistedMetaObject
		"""
		cdir = os.path.join( dirpath, settings.cmd.lib.paths.localdir )
		if not os.path.exists( cdir ):
			os.mkdir( cdir )
		volume = Volume()
		
		volume.key
		volume.set( 'path', dirpath )
		Volume.sync()
		return

		dbpath = os.path.join(cdir, 'volume.db')
		if os.path.exists(dbpath):
			log.warn("DB exists at %s", dbpath)
# initialize DB
		vdb = PersistedMetaObject.get_store('volume', dbpath)
		if 'mounts' not in lib.store.volumes:
			lib.store.volumes['mounts'] = []
		volumes = lib.store.volumes['mounts']
		if dbpath not in volumes:
			volumes.append(dbpath)
			lib.store.volumes['mounts'] = volumes
			lib.store.volumes.commit()
		#yield Keywords(lib=dict(stores=dict(volume=vdb)))
	   

