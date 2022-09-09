import os
import socket
import types
import re
from datetime import datetime

import zope.interface
from couchdb.mapping import Document
from sqlalchemy import func, text
from sqlalchemy.ext import declarative
#from sqlalchemy.ext.declarative import api # XXX: Py2
from sqlalchemy.orm.exc import NoResultFound

from script_mpe import log
from script_mpe.lib import type_ref
from .init import class_registry, SqlBase, get_session
from . import iface



# Util classes
class SessionMixin(object):

    sessions = {}

    @staticmethod
    def has_session(name='default'):
        return name in SessionMixin.sessions

    @staticmethod
    def get_session(name='default', dbref=None, init=False, metadata=SqlBase.metadata):
        if name not in SessionMixin.sessions:
            assert dbref, "session does not exists: %s" % name
            session = get_session(dbref, init, metadata=metadata)
            SessionMixin.sessions[name] = session
        else:
            session = SessionMixin.sessions[name]
            # XXX: assert session.engine, "existing session does not have engine"
        return session

    def add_self_to_session(self, name='default'):
        sa = self.__class__.get_session(name)
        if hasattr(self, 'init_defaults'):
            self.init_defaults()
        sa.add(self)


class ScriptModelFacade(object):

    """
    TODO: Using schemas from script-mpe, populate facade. Manage masterdb.
    XXX: probably move this to some kind of session

    On initialize, populate attr dict with each model class bound to its own
    canonical database.
    """

    def __init__(self, Root, masterdb):
        #version_tables = [ 'migrate_version', 'sa_migrate_version', ]
        #for k in version_tables:
        Space = Root._decl_class_registry.get('Space')
        self.spaces = Space.all(sa=masterdb)
        self.Root = Root
        self.masterdb = masterdb

    def init(self):
        """
        """
        subs = [
                'bookmarks',
        #        'budget',
        #        'db_sa',
                'domain2',
                'folder',
                'project',
                'todo',
                'topic'
            ]
        for modname in subs:
            self.init_sub(modname)

    def init_sub(self, name):
        ScriptMixin.start_session(name)

    def subs(self):
        for space in self.spaces:
            space

    def set_master(self):
        # TODO see if tis works for sqlite
        "ALTER TABLE %(table)s AUTO_INCREMENT = 1001;"

class ScriptMixin(SessionMixin):

    @classmethod
    def start_master_session(klass, name='cllct'):
        if name not in klass.sessions:
            session = klass.start_session(name)
        else:
            session = klass.sessions[name]

        master = ScriptModelFacade(klass, session)
        return master

    @classmethod
    def start_session(klass, name, dbref=None):
        if not dbref:
            schema = __import__(name)
            dbref = klass.assert_dbref(schema.__db__)
        session = klass.get_session(name, dbref)
        return session

    @staticmethod
    def assert_dbref(ref):
        if not re.match(r'^[a-z_][a-z0-9_+-]*://', ref):
            ref = 'sqlite:///' + os.path.expanduser(ref)
        return ref


class RecordMixin(object):

    def __init__(self):
        self.init_defaults()

    @classmethod
    def fetch(klass, filters=(), query=(), session='default', sa=None, exists=True):

        """
        Return exactly one or none for filtered query.
        """

        if not sa:
            sa = klass.get_session(session)

        rs = None

        if query:
            q = sa.query(*query)
        else:
            q = sa.query(klass)

        if filters:
            q = q.filter(*filters)

        try:
            rs = q.one()
        except NoResultFound as e:
            if exists:
                log.err("No results for %s.fetch(%r)", klass.__name__, filters)
                raise e

        return rs

    @classmethod
    def fetch_instance(klass, nid, session='default', sa=None):

        """
        """

        if not sa:
            sa = klass.get_session(session)
        q = sa.query(klass).filter(klass.__tablename__ + '.id' == nid)
        return q.one()

    @classmethod
    def get_instance(klass, _session='default', _sa=None, _fetch=True, **match_attrs):
        filters = []
        for attr in match_attrs:
            #filters.append( text(klass.__name__+'.'+attr+" = %r" % match_attrs[attr]) )
            filters.append( getattr(klass, attr) == match_attrs[attr] )

        rec = None
        if _fetch:
            rec = klass.fetch(filters, sa=_sa, session=_session, exists=False)

        if not rec:
            # FIXME: proper init per type, ie INode a/c/mtime
            for attr in 'date_updated', 'date_added':
                if attr not in match_attrs or not match_attrs[attr]:
                    match_attrs[attr] = datetime.now()

            rec = klass(**match_attrs)

        return rec

    @classmethod
    def find(klass, _sa=None, _session='default', _exists=False,
            _exact_match=True, **keys):

        """
        Return one (or none), with python keywords-to-like filters.
        """

        filters = []
        for k in keys:
            if _exact_match:
                filters.append(getattr(klass, k) == keys[k])
            else:
                filters.append(getattr(klass, k).like("%%%s%%" % keys[k]))
        return klass.fetch(filters=tuple(filters), sa=_sa, session=_session,
                exists=_exists)

    @classmethod
    def byKey(klass, key, session='default', sa=None, exists=False):
        filters = tuple( [
                getattr( klass, a ) == key[a]
                for a in key
            ] )
        return klass.fetch(filters, sa=sa, session=session, exists=exists)

    @classmethod
    def byName(klass, name=None, session='default', sa=None, exists=False):
        """
        Return one or none.
        """
        return klass.find(_sa=sa, _session=session, name=name)

    @classmethod
    def exists(klass, _sa=None, _session='default', **q):
        return klass.find(_sa=_sa, _session=_session, **q) != None

    @classmethod
    def last_id(klass, filters=None, session='default', sa=None):
        """
        Return last ID or zero.
        """
        if not sa:
            sa = klass.get_session(session)
        q = sa.query(func.max(klass.node_id))
        one = q.one()
        return one and one[0] or 0

    @classmethod
    def all(klass, filters=None, session='default', sa=None):
        """
        Return all for filtered query.
        """
        if not sa:
            sa = klass.get_session(session)
        q = sa.query(klass)
        if not filters and isinstance(filters, type(None)):
            if hasattr(klass, 'default_filters'):
                filters = klass.default_filters()
        if filters:
            for f in filters:
                q = q.filter(f)
        try:
            return q.all()
        except Exception as e:
            log.err("Error executing .all: %s", e)
            return []

    @classmethod
    def filter(klass, _filters=(), **keys):
        filters = list(_filters)
        for k in keys:
            filters.append(getattr(klass, k).like("%%%s%%" % keys[k]))
        return filters

    @classmethod
    def after_date(klass, dt, field='date_updated'):
        return ( getattr(klass, field) > dt, )

    @classmethod
    def before_date(klass, dt, field='date_updated'):
        return ( getattr(klass, field) < dt, )

    @classmethod
    def search(klass, _sa=None, _session='default', **keys):
        """
        Return all, with python keywords-to-filters.
        """
        filters = klass.filter(**keys)
        return klass.all(filters=tuple(filters), sa=_sa, session=_session)

    def taxus_id(self):
        """
        Return taxus record ID.. for nodes.. ?
        """
        return hex(id(self))
# XXX: is it possible to get the values in the primary key..
        #for colname in self.metadata.tables[self.__tablename__].primary_key.columns:
        print(dir(self.metadata.tables[self.__tablename__].primary_key.columns))
        print(self.metadata.tables[self.__tablename__].primary_key)
        print(self.metadata.tables[self.__tablename__].c)

        print(dir(self))
        return self.columns['id']

    registry = {}

    @classmethod
    def root_type(klass):

        """
        Return the most basic ORM model type for klass.

        Traverse its MRO, stop before Base or any *Mixin root and return
        the last class which is the same as or a supertype of given klass.
        """

        root = klass
        def test_base(mro):
            "Return true when front of list has basetype"
            assert len(mro) > 2, \
                    "Baseclass heuristic failed: MRO grew too small, %r" % mro
            # FIXME only detects 2-class inheritance and must list permutations
            return (
                    mro[2].__name__.endswith('Mixin') and mro[1].__name__ == 'Base'
                ) or (
                    mro[1].__name__.endswith('Mixin') and mro[2].__name__ == 'Base'
                )
        while not test_base(root.__mro__):
            root = root.__mro__[1]
        return root

    @classmethod
    def model_name(klass):
        return klass.root_type().__name__

    @classmethod
    def init_ref(klass, ref):
        """
        Return proper type and ID for ref::

            <polymorphic-identity>:<id>
            db:<tablename>:<id>

        """
        Root = klass.root_type()
        if not Root.registry:
            for key, model in list(SqlBase._decl_class_registry.items()):
                if not hasattr(model, '__mapper_args__'):
                    continue
                if 'polymorphic_identity' not in model.__mapper_args__:
                    poly_id = model.__tablename__
                else:
                    poly_id = model.__mapper_args__['polymorphic_identity']
                assert poly_id not in Root.registry
                Root.registry[poly_id] = model
        if ':' not in ref:
            poly_id, node_id = 'node', ref
        else:
            poly_id, node_id = ref.rsplit(':',1)
        Type = Root.registry[poly_id]
        return Type, node_id


class InstanceMixin(object):

    def commit(self, name='default'):
        session = SessionMixin.get_session(name=name)
        session.add(self)
        session.commit()


class ModelMixin(RecordMixin):

    # XXX: this does not work anymore after ids got unique values
    # not sure if this can be inferred, explicit is a bit crufty
    key_names = ['id']

    @classmethod
    def key(klass, self, key_names=None):
        key = {}
        if not key_names:
            key_names = self.key_names
        for a in key_names:
            key[a] = getattr(self, a)
        return key

    def recorded(self):
        return self.exists(self.key())

    @classmethod
    def className(klass):
        return klass.classPathname().split('.')[-1]

    @classmethod
    def classPathname(klass):

        """
        Hack to get the klass' name from its repr-string.
        """

        return repr(klass)[1:-1].split(' ')[1][1:-1]


class ORMMixin(ScriptMixin, InstanceMixin, ModelMixin):


    @staticmethod
    def keyid(*a):
        "Return unique ID for fields, for (couch) doc key"
        raise NotImplementedError

    @staticmethod
    def key(o):
        "Return unique ID for instance, for (couch) doc key"
        # E.g. return Bookmark.keyid(o.href)
        raise NotImplementedError


    @classmethod
    def keys(klass):
        "Return SQL columns"
        raise NotImplementedError


    doc_schemas = {}

    @classmethod
    def dict_(klass, doc, **dockeys):
        """
        Return the contructor keywods to (re)create a copy of the records
        """
        if not doc:
            return {}
        if isinstance(doc, dict):
            if 'type' in doc and doc['type']:
                pass # XXX: look for transform?
            return doc

        mod_name = type_ref(doc)
        if mod_name not in klass.doc_schemas \
        or len(klass.doc_schemas[mod_name]) < 1 \
        or not klass.doc_schemas[mod_name][0]:
            raise KeyError("Expected %s doc to dict" % ( mod_name ))

        return klass.doc_schemas[mod_name][0](doc)


    @classmethod
    def from_(klass, *docs, **dockeys):
        "Return new instance, getting options from doc"
        opts = klass.dict_(*docs, **dockeys)
        o = klass()
        for k, v in opts.items():
            setattr(o, k, v)
        return o

    @classmethod
    def forge(klass, source, settings, sa=None):
        o = klass.from_(source)
        o.init_defaults()
        if not settings.quiet:
            log.std("new: %s", o)
        if not settings.dry_run:
            if not sa:
                sa = klass.get_session(settings.session_name)
            sa.add(o)
        return o

    def to_dict(self, d={}):
        k = self.__class__.keys()
        for p in k:
            d[p] = getattr(self, p)
        return d

    def to_struct(self, d={}):
        return self.to_dict(d=d)

    def update_from(self, *docs, **dockeys):
        new = dict()
        for source in docs:
            # XXX: need an adapter for CouchDB docs
            #new.update(iface.IPyDict(source).items())
            if isinstance(source, Document):
                for k in source:#.keys():
                    if hasattr(source, k):
                        new[k] = getattr(source, k)
        new.update(dockeys)

        updated = False
        for k in new:
            # Cannot update attributes that don't exist
            if not hasattr(self, k): continue
            if getattr(self, k) != new[k]:
                print('updated', k, getattr(self, k), new[k])
                setattr(self, k, new[k])
                updated = True
        return updated



@zope.interface.implementer(iface.INodeSet)
class NodeSet(object):
    def __init__(self, iterable):
        self.nodes = iterable



class ResultSet(NodeSet):
    #zope.interface.implements(iface.INodeSet)
    def __init__(self, query, iterable):
        super(ResultSet, self).__init__(iterable)
        self.query = query


# TODO: move to lib.Prompt
def prompt_choice_with_input(promptstr, choices):
    assert isinstance(choices, list)
    i = 0
    for c in choices:
        i += 1
        promptstr += "\n%i. %s" % (i, c)
    x = input(promptstr+'\n')
    if x.isdigit():
        return choices[int(x)-1]
    elif x:
        return x

# from rsrlib plug net
def get_hostname():
    host = socket.gethostname().split('.').pop(0)
    getfqdn = socket.getfqdn()
    if getfqdn.split('.').pop(0) != host:
        print("Hostname does not match (sub)domain: %s (%s)"%(host, getfqdn))
        #err("Hostname does not match (sub)domain: %s (%s)", host, getfqdn)
    return host

def current_hostname(initialize=False, interactive=False):
    """
    """

    host = dict( name = get_hostname() )
    hostnameId = host['name'].lower()
    return hostnameId;

    # FIXME: current_hostname
    hostname = None

    hostname_file = os.path.expanduser('~/.cllct/host')
    if os.path.exists(hostname_file):
        hostname = open(hostname_file).read().strip()

    elif initialize:

        hostname = socket.gethostname()
        assert not isinstance(hostname, (tuple, list)), hostname
        log.debug(hostname)

        hostnames = socket.gethostbyaddr(hostname)
        while True:
            if socket.getfqdn() != hostname:
                hostname = hostnames[0] +"."
            else:
                log.err("FQDN is same as hostname")
                # cannot figure out what host to use
                while interactive:
                    hostname = prompt_choice_with_input("Which? ", hostnames[1])
                    if hostname: break
                #if not interactive:
                #    raise ValueError("")
            if hostname:
                try:
                    nameinfo((hostname, 80))
                except Exception as e:
                    print('Warning: Cannot resolve FQDN', e)
                open(hostname_file, 'w+').write(hostname)
                print("Stored %s in %s" % (hostname, hostname_file))
                break
    return hostname


class DNSLookupException(Exception):

    def __init__( self, addr, exc ):
        self.addr = addr
        self.exc = exc

    def __str__( self ):
        return "DNS lookup error for %s: %s" % ( self.addr, self.exc )

DNSCache = {}

def nameinfo(addr):
    try:
        DNSCache[ addr ] = socket.getaddrinfo(
            addr[ 0 ], addr[ 1 ], socket.AF_INET, socket.SOCK_STREAM )
    except Exception as e:
        raise DNSLookupException(addr, e)

    print(DNSCache[ addr ][ 0 ])

    family, socktype, proto, canonname, sockaddr = DNSCache[ addr ][ 0 ]


def sql_like_val(field, value, g):
    invert = value.startswith('!')
    if invert: value = value[1:]
    if '*' in value:
        filter = field.like( value.replace('*', '%') )
    elif g.partial_match:
        filter = field.like( '%'+value+'%' )
    else:
        filter = field == value
    if invert:
        return ~ filter
    return filter
