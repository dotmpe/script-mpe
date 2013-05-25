"""
Object-Storage mapping.

PMO is included at various places but not actively used.
Started first use in Metafile. Later solution for Volume, other files may be
looked for.
"""
import shelve
import bsddb
import hashlib

from rsrlib.store import UpgradedPickle, Object


class PersistedMetaObject(Object):

	stores = {}
	"list of loaded stores (static) class scope"
	default_store = 'default'
	"name of default store, to customize per type"

	@classmethod
	def get_store(Klass, name=None, dbref=None, ro=False):
		"""
		Generic routine to instantiate new stores,
		each session is named and kept in PMO.stores.
		Default is 'rw', and ofcourse one session per name.
		"""
		if not name:
			name = Klass.default_store
		if name not in PersistedMetaObject.stores:
			print PersistedMetaObject.stores
			assert dbref, "store does not exists: %s" % name
			try:
				store = shelve.open(dbref, 
				# read-only, or create if not exist and open read/write
						ro and 'r' or 'n') 
			except bsddb.db.DBNoSuchFileError, e:
				assert not e, "cannot open store: %s, %s, %s" %(name, dbref, e)
			PersistedMetaObject.stores[name] = store
		else:
			store = PersistedMetaObject.stores[name]
		return store


