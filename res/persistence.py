"""
Object-Storage mapping.
"""
import shelve
import bsddb

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

    def load(self, name=None):
        store = PersistedMetaObject.get_store(name=name)
        store[self.key()] = self

