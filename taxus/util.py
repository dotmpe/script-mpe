import os
import socket
import types

import zope.interface
from sqlalchemy.orm.exc import NoResultFound

from script_mpe import log
from init import get_session
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

    def commit(self, name='default'):
        session = SessionMixin.get_session(name=name)
        session.add(self)
        session.commit()

    @classmethod
    def fetch(Klass, filters=(), sa=None, session='default', exists=True):
        """
        Return exactly one or none for filtered query.
        """
        if not sa:
            sa = Klass.get_session(session)
        rs = None
        try:
            rs = sa.query(Klass)\
                .filter(*filters)\
                .one()
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
    def byKey(Klass, key, sa=None, session='default', exists=False):
        filters = tuple( [
                getattr( Klass, a ) == key[a]
                for a in key
            ] )
        return Klass.fetch(filters, sa=sa, session=session, exists=exists)

    @classmethod
    def byName(Klass, name=None, sa=None, session='default', exists=False):
        """
        Return one or none.
        """
        return Klass.fetch((Klass.name == name,), sa=sa, session=session,
                exists=exists)

    @classmethod
    def exists(Klass, keydict):
        return Klass.fetch(keydict, sa=sa, session=session) != None

    def recorded(self):
        return self.exists(self.key())

    @classmethod
    def all(Klass, filters=None, sa=None, session='default'):
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
            log.err("Error executing SessionMixin.all: %s", e)
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

def current_hostname(initialize=False, interactive=False):
    """
    """
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


