import os
import socket
import types
import re

import zope.interface

from sqlalchemy import func
from sqlalchemy.ext import declarative
from sqlalchemy.ext.declarative import api
from sqlalchemy.orm.exc import NoResultFound

import taxus
from script_mpe import log
from init import class_registry, SqlBase, get_session
import iface



# Util classes
class SessionMixin(object):

    sessions = {}

    @staticmethod
    def get_session(name='default', dbref=None, init=False):
        if name not in SessionMixin.sessions:
            assert dbref, "session does not exists: %s" % name
            session = get_session(dbref, init)
            #assert session.engine, "new session has no engine"
            SessionMixin.sessions[name] = session
        else:
            session = SessionMixin.sessions[name]
            #assert session.engine, "existing session does not have engine"
        return session


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
    def start_master_session(Klass, name='cllct'):
        if name not in Klass.sessions:
            session = Klass.start_session(name)
        else:
            session = Klass.sessions[name]

        master = ScriptModelFacade(Klass, session)
        return master

    @classmethod
    def start_session(Klass, name, dbref=None):
        if not dbref:
            schema = __import__(name)
            dbref = Klass.assert_dbref(schema.__db__)
        session = Klass.get_session(name, dbref)
        return session

    @staticmethod
    def assert_dbref(ref):
        if not re.match(r'^[a-z][a-z]*://', ref):
            ref = 'sqlite:///' + os.path.expanduser(ref)
        return ref


class RecordMixin(object):

    @classmethod
    def get_instance(Klass, nid, session='default', sa=None):

        """
        """

        if not sa:
            sa = Klass.get_session(session)
        q = sa.query(Klass).filter(Klass.__tablename__ + '.id == ' + nid)
        return q.one()

    @classmethod
    def fetch(Klass, filters=(), query=(), session='default', sa=None, exists=True):

        """
        Return exactly one or none for filtered query.
        """

        if not sa:
            sa = Klass.get_session(session)

        rs = None

        if query:
            q = sa.query(*query)
        else:
            q = sa.query(Klass)

        if filters:
            q = q.filter(*filters)

        try:
            rs = q.one()
        except NoResultFound, e:
            if exists:
                log.err("No results for %s.fetch(%r)", Klass.__name__, filters)
                raise e

        return rs

    @classmethod
    def find(Klass, _sa=None, _session='default', _exists=False, **keys):

        """
        Return one (or none), with python keywords-to-like filters.
        """

        filters = []
        for k in keys:
            filters.append(getattr(Klass, k).like("%%%s%%" % keys[k]))
        return Klass.fetch(filters=tuple(filters), sa=_sa, session=_session,
                exists=_exists)

    @classmethod
    def byKey(Klass, key, session='default', sa=None, exists=False):
        filters = tuple( [
                getattr( Klass, a ) == key[a]
                for a in key
            ] )
        return Klass.fetch(filters, sa=sa, session=session, exists=exists)

    @classmethod
    def byName(Klass, name=None, session='default', sa=None, exists=False):
        """
        Return one or none.
        """
        return Klass.fetch((Klass.name == name,), sa=sa, session=session,
                exists=exists)

    @classmethod
    def exists(Klass, keydict):
        return Klass.fetch(keydict, sa=sa, session=session) != None

    @classmethod
    def last_id(Klass, filters=None, session='default', sa=None):
        """
        Return last ID or zero.
        """
        if not sa:
            sa = Klass.get_session(session)
        q = sa.query(func.max(Klass.node_id))
        one = q.one()
        return one and one[0] or 0

    @classmethod
    def all(Klass, filters=None, session='default', sa=None):
        """
        Return all for filtered query.
        """
        if not sa:
            sa = Klass.get_session(session)
        q = sa.query(Klass)
        if not filters and isinstance(filters, types.NoneType):
            if hasattr(Klass, 'default_filters'):
                filters = Klass.default_filters()
        if filters:
            for f in filters:
                q = q.filter(f)
        try:
            return q.all()
        except Exception, e:
            log.err("Error executing .all: %s", e)
            return []

    @classmethod
    def search(Klass, _sa=None, _session='default', **keys):
        """
        Return all, with python keywords-to-filters.
        """
        filters = []
        for k in keys:
            filters.append(getattr(Klass, k).like("%%%s%%" % keys[k]))
        return Klass.all(filters=tuple(filters), sa=_sa, session=_session)

    def taxus_id(self):
        """
        Return taxus record ID.. for nodes.. ?
        """
        return hex(id(self))
# XXX: is it possible to get the values in the primary key..
        #for colname in self.metadata.tables[self.__tablename__].primary_key.columns:
        print dir(self.metadata.tables[self.__tablename__].primary_key.columns)
        print self.metadata.tables[self.__tablename__].primary_key
        print self.metadata.tables[self.__tablename__].c

        print dir(self)
        return self.columns['id']

    registry = {}

    @classmethod
    def root_type(Klass):

        """
        Return the most basic ORM model type for Klass.

        Traverse its MRO, stop before Base or any *Mixin root and return
        the last class which is the same as or a supertype of given Klass.
        """

        root = Klass
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
    def init_ref(Klass, ref):
        """
        Return proper type and ID for ref::

            <polymorphic-identity>:<id>
            db:<tablename>:<id>

        """
        Root = Klass.root_type()
        if not Root.registry:
            for key, model in SqlBase._decl_class_registry.items():
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
    def key(Klass, self, key_names=None):
        key = {}
        if not key_names:
            key_names = self.key_names
        for a in key_names:
            key[a] = getattr(self, a)
        return key

    def recorded(self):
        return self.exists(self.key())

    @classmethod
    def className(Klass):
        return Klass.classPathname().split('.')[-1]

    @classmethod
    def classPathname(Klass):

        """
        Hack to get the Klass' name from its repr-string.
        """

        return repr(Klass)[1:-1].split(' ')[1][1:-1]


class ORMMixin(ScriptMixin, InstanceMixin, ModelMixin):
    pass





class NodeSet(object):
    zope.interface.implements(iface.INodeSet)
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
    x = raw_input(promptstr+'\n')
    if x.isdigit():
        return choices[int(x)-1]
    elif x:
        return x

# from rsrlib plug net
def get_hostname():
    host = socket.gethostname().split('.').pop(0)
    getfqdn = socket.getfqdn()
    if getfqdn.split('.').pop(0) != host:
        print "Hostname does not match (sub)domain: %s (%s)"%(host, getfqdn)
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
                except Exception, e:
                    print 'Warning: Cannot resolve FQDN', e
                open(hostname_file, 'w+').write(hostname)
                print "Stored %s in %s" % (hostname, hostname_file)
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
    except Exception, e:
        raise DNSLookupException(addr, e)

    print DNSCache[ addr ][ 0 ]

    family, socktype, proto, canonname, sockaddr = DNSCache[ addr ][ 0 ]


