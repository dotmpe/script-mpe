import os
import socket

import zope.interface
from sqlalchemy.orm.exc import NoResultFound

import log
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

    def key(self):
        key = {}
        for a in self.key_names:
            key[a] = getattr(self, a)
        return key

    def commit(self, name='default'):
        session = SessionMixin.get_session(name=name)
        session.add(self)
        session.commit()

    @classmethod
    def fetch(Klass, filters=(), sa=None, session='default', exists=True):
        """
        Return exactly one.
        """
        if not sa:
            sa = Klass.get_session(session)
        rs = None
        try:
            rs = sa.query(Klass)\
                .filter(*filters).one()
        except NoResultFound, e:
            if exists:
                log.err("No results for %s.fetch(%s)", Klass.__name__, filters)
                raise e
        return rs

    @classmethod
    def find(self, filters=None, sa=None, session='default'):
        """
        Return one or none.
        """
        return self.fetch(filters, sa=sa, session=session, exists=False)

    @classmethod
    def byName(self, name=None, sa=None, session='default'):
        """
        Return one or none.
        """
        return self.fetch((Klass.name == name,), sa=sa, session=session, exists=False)

    @classmethod
    def exists(Klass, keydict):
        return Klass.fetch(keydict, sa=sa, session=session) != None

    def recorded(self):
        return self.exists(self.key())

    @classmethod
    def search(Klass, name=None):
        if name:
            rs = sa.query(Klass)\
                    .filter(Klass.name.like("%%%s%%" % name))\
                    .all()
            return rs

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


