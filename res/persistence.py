"""
Object-Storage mapping.

TODO: confine to basedir, prolly sort by type too.
TODO: dirty state tracking for better sync. impl.
XXX: What to do about different classes sharing dbsessions.
     
"""
import os
import bsddb
import inspect
import shelve

import confparse
from rsrlib.store import UpgradedPickle, Object


class PersistedMetaObject(Object):

    """
    Manage shelves (anydb's with pickled objects).

    Typical session:
        >>> db = PersistedMetaObject.get_store('my', './my.db') 
        >>> db['key'] = 123
        >>> PersistedMetaObject.sync()
        >>> PersistedMetaObject.close()
        
    PersistedMetaObject is generic and has no indices.
    """
    # XXX: inheritance of UpgradedPickle, Object is symbolic for now

    # Static

    indices = (
            )
#    shelves = (
#            )
    """
    Shelves for keys or list of keys.
    """
    @classmethod
    def get_indices(Klass, self):
        return Klass.indices# + Object.get_indices()


    persistence = confparse.Values(dict(
        stores = {},
        #"dbref to shelve instance map"
        sessions = {},
        #"name to dbref"
        default_store = 'default',
        #"name of default store, to customize per type"
    ))

    @classmethod
    def get_store(Klass, name=None, dbref=None):
        """
        Generic shelve session management.
        Name + dbref initialize if needed.
        Always returns instance for Name, which must be initialized.
        """
        if not name:
            name = Klass.persistence.default_store
        if name not in Klass.persistence.sessions:
            assert dbref, "store does not exists: %s" % name
            if dbref not in Klass.persistence.stores:
                try:
                    store = shelve.open(dbref)#, writeback=True)
                except bsddb.db.DBNoSuchFileError, e:
                    assert not e, "cannot open store: %s, %s, %s" %(name, dbref, e)
                setattr(Klass.persistence.stores, dbref, store)
            else:
                store = Klass.persistence.stores[dbref]
            Klass.persistence.sessions[name] = dbref
        else:
            storedb = Klass.persistence.sessions[name]
            if dbref:
                assert dbref == storedb
            store = Klass.persistence.stores[storedb]
        return store

    shelves = (
        # anywhere or Volume.shelves?
#            ('Volume.vpath', 'objects'),
#                ('Volume.vtype', 'index'),
#
#            ('Metafile.sid', 'objects'),
#                ('Metafile.sha1', 'index'),
#                ('Metafile.tth', 'index'),
#                ('Metafile.crc', 'index'),
#                ('Metafile.first20', 'index'),
#                ('Metafile.size', 'index'),
#                ('Metafile.md5', 'index'),
        )
    """
    Turn Klass.name into factory for shelved objects,
    or for shelved keys or lists of keys.
   
    Each object may have its own type of key, but only one key and one
    objects shelve associtated with its class.

    The object API is:
        >>> assert Klass.key() == "mykey"
        >>> myobj = Klass.objects[key] 
        >>> myobj == Klass.fetch('mykey', key)
        True
        >>> myobj.attr = 'update' # XXX detect and commit on close
        >>> myobj.commit() #or 
        >>> Klass.store[key] = myobj; Klass.store.sync() #?

    and the index API:                
        >>> obj2 = Klass.fetch('sha1', 'abcdef') # raise keyerr if not found
        >>> obj3 = Klass.find('sha1', 'abcdef') # return none if not found

    and the bare shelves:
        >>> key = Klass.indices.{sha1,tth,..}[value]
        >>> keys = Klass.indices.{size,crc,type}[value]

    usage:
        >>> obj = Klass(new_key)
        >>> obj.sha1 = 'abcdef'
        >>> obj.commit()
        >>> obj == obj2 == obj3 
        True

    Iow. each klass has a distinct list of shelves to which instances of
    itself are stored, and which contain the indices of specific values to
    keys. The opened shelves are kept in a pool and the klass attribute
    should be regarded a (secondary) reference. The primary location of 
    all shelve sessions is PersistedMetaObject.

    The ID of the shelve is provided by the class declaration, 
    the filesystem location is given in config or cmdline options and 
    provided for by cmd:lib.

    The API requires some kind of getter/setter mechanism to hook into:

    >>> PersistedMetaObject.set_index(name, value, key)
    >>> PersistedMetaObject.update_index(name, value, old, new)

    for each of the registered indices, but the actual structure of the
    PersistedMetaObject object is not further defined here than
    that the 'store' and 'indices' attribute names are reserved and
    'key()' is a required implementation.
    """ 


    stores = confparse.Values({})

    @classmethod
    def init(Klass, conf):
        """
        Prepare shelves for this class inheritance chain.
        Shelves are initialized to the 'stores' attribute of the class
        that contains the 'indices' listing.
        """
        for C in inspect.getmro(Klass):
            klass = Klass.__name__
            klass = C.__name__
            if not hasattr(C, 'indices'):
                print 'warn: no indices for %s (%s)'%(klass,C.__module__)
                continue
            for idxname, idxtype in C.indices:
                dbdir = os.path.expanduser(conf.cmd.lib.shelves[klass])
                assert isinstance(dbdir, basestring), dbdir
                if idxtype == 'index':
                    dbname = getattr(conf.cmd.lib, idxtype).tpl% {
                            'klass': klass, 'name': idxname
                        }
                else:
                    dbname = getattr(conf.cmd.lib, idxtype).tpl% {'klass':klass}
                dbref = os.path.join(dbdir, dbname)
#                print 'Init:', klass, idxname, idxtype, dbref
                store = Klass.get_store(idxname, dbref)
                assert not hasattr(Klass.stores, idxname), idxname
                setattr(Klass.stores, idxname, store)
                if idxtype != 'index':
                    assert not hasattr(Klass, 'key')
                    assert not hasattr(Klass.stores, 'objects')
                    setattr(Klass, 'key', idxname)
                    setattr(Klass.stores, 'objects', store)
    
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
        The proper way to initialize a persisted object.
        """
        if not session:
            session = Klass.default
        return session[key]

#    @classmethod
#    def fetch_key(Klass, idxname, value, session=None, typ=None):
#        return Klass.find(session, idxname, value, typ, True)

    @classmethod
    def find(Klass, session, idxname, value, typ=None, require=False):
        """
        Search specific index for an object key.
        """
        if not typ: 
            # Just inherit PersistedMetaObject, no need to use 'typ'
            typ = Klass

        idx = getattr(typ.stores, idxname)

        if not require and value not in idx:
            return
        assert not require or value in idx, \
            "Index %r does not have %r" %(idxname, value)

        # retrieve the object key
        objkey = idx[value]

        if not session:
            session = 'default'
        if isinstance(session, basestring):
            session = typ.get_store(session)

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
        Get the indexname for the class, and set the value
        of the current object in that index.
        """
        print 'set', self, idxname, value
        Klass = self.__class__
        return
        #if idxname == Klass.stores.key:'objects':
        idx = getattr(Klass.stores, idxname)
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


