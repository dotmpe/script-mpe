"""
Object-Storage mapping.
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
	def get_store(Klass, name=None, dbref=None):
		if not name:
			name = Klass.default_store
		if name not in PersistedMetaObject.stores:
			assert dbref, "store does not exists: %s" % name
			try:
				store = shelve.open(dbref)
			except bsddb.db.DBNoSuchFileError, e:
				assert not e, "cannot open store: %s, %s, %s" %(name, dbref, e)
			PersistedMetaObject.stores[name] = store
		else:
			store = PersistedMetaObject.stores[name]
		return store

	# Object does not implement these yet. Once a framework may be established
	# here, then see how rsrlib's future fares.

		store = PersistedMetaObject.get_store(name=self.storage)

	def metaid(self):
		"""
		Id that changes depending on path location.
		"""
		return hashlib.md5(self.path).hexdigest()

	def init(self):
		pass

	def fetch(self):
		mid = self.metaid()
		#if mid in ...

	def store(self):
		mid = self.metaid()
		self.shelve[mid] = self
		self.shelve.sync()



