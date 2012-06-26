"""
Object-Storage mapping.
"""
import shelve
import bsddb

from rsrlib.store import UpgradedPickle, Object


class PersistedMetaObject(Object):

    stores = {}
    "list of loaded stores (static) class scope"
    sessions = {}
    "list of loaded stores (static) class scope"
    default_store = 'default'
    "name of default store, to customize per type"

    @classmethod
    def get_store(Klass, name=None, dbref=None):
        if not name:
            name = Klass.default_store
        if name not in PersistedMetaObject.sessions:
            assert dbref, "store does not exists: %s" % name
            if dbref not in PersistedMetaObject.stores:
                try:
                    store = shelve.open(dbref)
                except bsddb.db.DBNoSuchFileError, e:
                    assert not e, "cannot open store: %s, %s, %s" %(name, dbref, e)
                PersistedMetaObject.stores[dbref] = store
            else:
                store = PersistedMetaObject.stores[dbref]
            PersistedMetaObject.sessions[name] = store
        else:
            store = PersistedMetaObject.sessions[name]
        return store

    def load(self, session=None):
        store = PersistedMetaObject.get_store(name=session)
        store[self.key()] = self

