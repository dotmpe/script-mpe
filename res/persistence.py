"""
Object-Storage mapping.

PMO is included at various places but not actively used.
Started first use in Metafile. Later solution for Volume, other files may be
looked for.
"""
import shelve
import hashlib



class UpgradedPickle:

    """
    Use get/set state hooks provided for by pickle library to provide
    up/downgrade migration for data.
    """

    version_key = 'version'
    version = 0
    upgrades = {
        0: lambda obj: obj,
    }

    def __getstate__(self):
        """
        Return object for pickling.
        """
        return self.__upgradestate(self.__dict__)

    def __setstate__(self, state):
        """
        Reinitialize from pickled object .
        """
        self.__upgradestate(state)
        self.__dict__ = state

    def __upgradestate(self, state):
        if self.version_key not in state:
            state[self.version_key] = 0
        while state[self.version_key] != self.version:
            upgrade = self.__class__.upgrades[state[self.version_key]]
            state = upgrade(state)
        assert state[self.version_key] == self.version
        return state


class Object(object, UpgradedPickle):

    store = None

    def objectid(self):
        return id(self)

    def exists(self):
        return self.objectid() in self.store

    @classmethod
    def fetch(clss, object_id, store=None):
        "Return object from local PMO-store"
        if not store:
            store = clss.store
        object_id = self.objectid()
        if object_id in self.store:
            return self.store[object_id]

    def store(self):
        """
        """
        self.store[self.object_id()] = self
        self.store.sync()

    def init(self):
        """
        Create the object for the current context.
        """
        raise NotImplemented


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
            import bsddb3 as bsddb
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



