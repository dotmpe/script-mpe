"""
Object-Storage mapping.

TODO: dirty state tracking for better sync. impl.
XXX: What to do about different classes sharing dbsessions.
     
"""
import shelve
import bsddb

from rsrlib.store import UpgradedPickle, Object


class PersistedMetaObject(Object):

    """
    Manage shelves (anydb's with pickled objects).

    This utilizes a secondary class to enable lookup on 
    various object fields, called PersistedMetaIndex.
    """

    # XXX: inheritance of UpgradedPickle, Object is symbolic for now

    # Static

    stores = {}
    "list of loaded stores (static) class scope"
    sessions = {}
    "list of loaded stores (static) class scope"
    default_store = 'default'
    "name of default store, to customize per type"

    @classmethod
    def get_store(Klass, name=None, dbref=None):
        """
        Generic shelve session management.
        """
        if not name:
            name = Klass.default_store
        if name not in PersistedMetaObject.sessions:
            assert dbref, "store does not exists: %s" % name
            if dbref not in PersistedMetaObject.stores:
                try:
                    store = shelve.open(dbref)#, writeback=True)
                except bsddb.db.DBNoSuchFileError, e:
                    assert not e, "cannot open store: %s, %s, %s" %(name, dbref, e)
                PersistedMetaObject.stores[dbref] = store
            else:
                store = PersistedMetaObject.stores[dbref]
            PersistedMetaObject.sessions[name] = store
        else:
            store = PersistedMetaObject.sessions[name]
        return store

    indices = (
            'inode',# 'PersistedMetaIndex', 'inode'),
            'sha1_content_digest',# 'KeyedHeaderIndex', 'Digest:sha1'),
            'md5_content_digest',# 'KeyedHeaderIndex', 'Digest:md5'),
        )

    @classmethod
    def init(Klass):
        """
        Prepare this class, run for each class that defines an indices
        array.
        """
        default = Klass.get_store('default', '.cllct/objects.db')
        klass = Klass.__name__
        setattr(Klass, 'default-'+klass, default)
        for idxname in Klass.indices:
            store = Klass.get_store(idxname, 
                    '.cllct/index-'+klass+'-'+idxname+'.db')
            setattr(Klass, idxname, store)
       
    @classmethod
    def sync(Klass):
        """
        """
        Klass.default.sync()
        for idxname in Klass.indices:
            getattr(Klass, idxname).sync()

    @classmethod
    def unload(Klass):
        """
        Flush and close all stores.
        """
        #Klass.sync()
        Klass.default.close()
        delattr(Klass, 'default')
        for idxname in Klass.indices:
            getattr(Klass, idxname).close()
            delattr(Klass, idxname)

    @classmethod
    def exists(Klass, key, session=None):
        if not session:
            session = Klass.default
        return key in session

    @classmethod
    def fetch(Klass, key, session=None):
        """
        The proper way to initialize a persited object.
        """
        if not session:
            session = Klass.default
        return session[key]

    @classmethod
    def find(Klass, session, idxname, value, typ=None):
        """
        Search specific index for an object key.
        """
        if not typ: 
            # Just inherit PersistedMetaObject, no need to use 'typ'
            typ = Klass
        idx = getattr(typ, idxname)

        assert value in idx, "Index %r does not have %r" %(idxname, value)
        objkey = idx[value]

        if not session:
            session = 'default'
        if isinstance(session, basestring):
            session = PersistedMetaObject.get_store(session)

        assert objkey in Klass.default
        assert objkey in session, "Value %r found for %s in %r not a known object" %(
                objkey, typ, idxname)
        return session[objkey]


    # Instance

    def __init__(self, new=False):
        #self.updated = False 
        pass

    def store(self, session=None):
        """
        """
        store = PersistedMetaObject.get_store(name=session)
        store[self.key()] = self
        for idxname in self.indices:
            getattr(self.__class__, idxname).sync()

#    @property
#    def inSync(self):
#        """
#        Persisted object exists and object was not updated.
#        """
#        default = PersistedMetaObject.get_store('default')
#        return self.name in default and not self.updated

    def __str__(self):
        return "MyObj[%s;]" % ( self.key(), )

    def set(self, idxname, value):
        """
        """
        Klass = self.__class__
        idx = getattr(Klass, idxname)
        if value in idx:
            objkey = idx[value]
            assert objkey == self.key(),\
                    "%s: cannot overwrite value for other object: %s.test=%s" %\
                    (self, objkey, value)
        if idxname in self.__dict__:
            old = self.__dict__[idxname]
            assert idx[old] == self.key(),\
                    "Can only replace indexed value for this class, not %s" % (
                            idx[old] )
            del self.__dict__[idxname]
            print 'Deleting', old
            del idx[old]
        self.__dict__[idxname] = value
        idx[value] = self.key()

    def get(self, idxname):
        if idxname not in self.__dict__: # lazy load
            Klass = self.__class__
            idx = getattr(Klass, idxname)
            value = idx[self.key()]
            self.__dict__[idxname] = value
        return getattr(self, idxname)




# TEST

class MyObj(PersistedMetaObject):

    indices = (
            'this',
        )

    def __init__(self, name):
        super(PersistedMetaObject, self).__init__()
        self.name = name
        self.data = {}

    def key(self):
        """
        Return the object id.
        """
        return self.name



if __name__ == '__main__':

    def init(suffix='1'):
        if MyObj.exists('name'+suffix):
            obj = MyObj.fetch('name'+suffix)
        else:
            obj = MyObj('name'+suffix)
            obj.store()
            obj.set('this', 'key'+suffix)
            obj.store()
        return obj
    def fetch(suffix):
        obj = MyObj.fetch('name'+suffix)
        return obj
    def find(suffix):
        return MyObj.find('', 'this', 'key'+suffix)

    #shelve = PersistedMetaObject.get_store('default')
    #print PersistedMetaObject.find(shelve, 'this', 'key3', MyObj)
    #print PersistedMetaObject.find(shelve, 'this', 'key1', MyObj)
    #print PersistedMetaObject.find(shelve, 'this', 'key2', MyObj)

    MyObj.init()

#    print init('1')
#    print init('2')
#    print init('3')

    print fetch('1')
    print fetch('2')
    print fetch('3')

    print find('1')
    print find('2')
    print find('3')

    MyObj.unload()


