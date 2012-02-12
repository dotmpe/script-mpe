#!/usr/bin/env python
"""
Taxus ORM (SQL) model.

All objects inherit from Node. Each object type is has its own table. Stored
objects have records in `nodes` and all other 'parent' tables (references via
foreign-keys). The `nodes` table stores the objects type, meaning there can be 
only one type for a node record at any time.

TODO: redraw this diagram.
Inheritance hierarchy and relations::


                          Node
                           * name:String(255)
                           * type
                           * date-added
                           * (date-)deleted

                               A
                               |
           .--------------- .--^--------. ----------. --------.
           |                |           |           |         | 
          INode             |          Status      Locator    | 
           * local_path     |           * nr        * ref     | 
           * ntype          |                       * checksums  
           * size           |           ^                     |
           * cum_size       |           |           ^         |
                            |           |           |         | 
        A             V     |           |           |         | 
        |             |     |           |           |         | 
     CachedContent    |    Resource     |           |         |    
      * cid           |     * status ---/           |         |        
      * size          |     * location -------------/         | 
      * charset       |     * last/a/u-time         |         |  
      * partial       |     * allowed               |         | 
      * expires       |                             |         |
      * etag          |     A                       |         |
                      |     |                       |         | 
      ^               /-----|-----------------------/   /--< Description
      |               |     |                       |   |     * namespace:Namespace
      |  Invariant ---|-----'---- Variant           |   |      
      \-- * content   |     |      * vary           |   |     A               
          * mediatype |     |      * descriptions >-|---/     |         
          * languages |     |                       |         '-- Comment       
                      |     |      A                |         |    * node:Node
                      ^     |      |                |         |    * comment:Text
                            |      |                |         |     
               Checksum     |     Namespace         |         '-- ...
                * sha1      |      * prefix:String  |         * subject    
                * md5       |                       |         * predicate   
                            '---- Relocated         |         * object     
                            |      * redirect ------/
                            |      * temporary:Bool
                            |                                                   
                            '---- Bookmark                   Formula         
                                                              * statements
                                                                                  


This schema will make node become large very quickly. Especially as various
metadata relations between Nodes are recorded in Statements.
In addition, Statements will probably rather refer to Fragment nodes rather than 
Resource nodes, adding another layer of similar but distinct nodes.

The Description column in the diagram is there to get an idea, while most such
data should be stored a suitable triple store.

TODO: move all models to _model module.
"""
import sys
import os
from datetime import datetime
import socket

import zope.interface
from sqlalchemy import Column, Integer, String, Boolean, Text, \
    ForeignKey, Table, Index, DateTime, \
    create_engine
from sqlalchemy.orm.exc import NoResultFound
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship, backref, sessionmaker

#from debug import PrintedRecordMixin 

import taxus_out
import libcmd
from libcmd import Cmd, err

SqlBase = declarative_base()


# Util classes
class SessionMixin(object):

    sessions = {}

    @staticmethod
    def get_instance(name='default', dbref=None):
        if name not in SessionMixin.sessions:
            assert dbref, "session does not exists: %s" % name
            session = get_session(dbref)
            #assert session.engine, "new session has no engine"
            SessionMixin.sessions[name] = session
        else:
            session = SessionMixin.sessions[name]
            #assert session.engine, "existing session does not have engine"
        return session

    # 
    key_names = ['id']

    def key(self):
        key = {}
        for a in self.key_names:
            key[a] = getattr(self, a)
        return key

    def commit(self):
        session = SessionMixin.get_instance()
        session.add(self)
        session.commit()

    def fetch(self):
        session = SessionMixin.get_instance()
        keydict = self.key()
        return session.query(self.__class__).filter(**keydict).one()
        
    def exists(self):
        return self.fetch() != None 


class NodeSet(object):
    zope.interface.implements(taxus_out.INodeSet)
    def __init__(self, iterable):
        self.nodes = iterable

class ResultSet(NodeSet):
    #zope.interface.implements(taxus_out.INodeSet)
    def __init__(self, query, iterable):
        super(ResultSet, self).__init__(iterable)
        self.query = query


class Node(SqlBase, SessionMixin):

    zope.interface.implements(taxus_out.INode)

    __tablename__ = 'nodes'
    id = Column(Integer, primary_key=True)

    discriminator = Column('type', String(50))
    __mapper_args__ = {'polymorphic_on': discriminator}
    
    name = Column(String(255), nullable=True)
    
    #space_id = Column(Integer, ForeignKey('nodes.id'))
    #space = relationship('Node', backref='children', remote_side='Node.id')
    
    date_added = Column(DateTime, index=True, nullable=False)
    deleted = Column(Boolean, index=True, default=False)
    date_deleted = Column(DateTime)


class ID(SqlBase, SessionMixin):

    """
    A global identifier.
    """

    zope.interface.implements(taxus_out.IID)

    __tablename__ = 'ids'
    id = Column(Integer, primary_key=True)

    discriminator = Column('type', String(50))
    __mapper_args__ = {'polymorphic_on': discriminator}

    date_added = Column(DateTime, index=True, nullable=False)
    deleted = Column(Boolean, index=True, default=False)
    date_deleted = Column(DateTime)


class Name(ID):

    """
    A global identifier name.
    """

    __tablename__ = 'ids_name'
    __mapper_args__ = {'polymorphic_identity': 'name'}

    name_id = Column('id', Integer, ForeignKey('ids.id'), primary_key=True)

    name = Column(String(255), index=True, unique=True)


# mapping table for Checksum [1-*] Locator
locator_checksum = Table('locator_checksum', SqlBase.metadata,
    Column('locator_ida', ForeignKey('ids_lctr.id')),
    Column('chk_idb', ForeignKey('chks.id'))
)

class Locator(ID):

    """
    A global identifier for retrieval of remote content.
    """

    __tablename__ = 'ids_lctr'
    __mapper_args__ = {'polymorphic_identity': 'locator'}

    locator_id = Column('id', Integer, ForeignKey('ids.id'), primary_key=True)

    ref = Column(String(255), index=True, unique=True)
   
    checksums = relationship('Checksum', secondary=locator_checksum,
        backref='locator')


class Host(Node):
    """
    """
    __tablename__ = 'hosts'
    __mapper_args__ = {'polymorphic_identity': 'host'}

    host_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)
    hostname_id = Column(Integer, ForeignKey('ids_name.id'))
    hostname = relationship(Name, primaryjoin=hostname_id==Name.name_id)

    @classmethod
    def current(klass, session):
        hostname_ = current_hostname()
        hostname = session.query(Name)\
            .filter(Name.name == hostname_).one()
        return session.query(klass).filter(Host.hostname == hostname).one()

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
        print hostname

        hostnames = socket.gethostbyaddr(hostname)
        if socket.getfqdn() != socket.gethostname():
            hostname = hostnames[0] +"."
        else:
            err("FQDN is same as hostname")
            # cannot figure out what host to use
            while interactive:
                print hostnames
                hostname = prompt_choice_with_input("Which? ", hostnames[1])
                if hostname: break
            #if not interactive:
            #    raise ValueError("")
        if hostname:
            open(hostname_file, 'w+').write(hostname)
            print "Stored %s in %s" % (hostname, hostname_file)
    return hostname

class INode(Node):

    __tablename__ = 'inodes'
    __mapper_args__ = {'polymorphic_identity': 'inode'}

    inode_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)
    inode_number = Column(Integer, unique=True)

    #filesystem_id = Column(Integer, ForeignKey('nodes.id'))

    itype = Column(Integer, index=True, unique=True)
    local_path = Column(String(255), index=True, unique=True)

    host_id = Column(Integer, ForeignKey('hosts.id'))
    host = relationship(Host, primaryjoin=Host.host_id==host_id)


# mapping table for Checksum [1-*] INode 
#inode_checksum = Table('inode_checksum', SqlBase.metadata,
#    Column('inode_ida', ForeignKey(INode.inode_id)),
#    Column('chk_idb', ForeignKey('chks.id'))
#)

class Checksum(Node):

    __tablename__ = 'chks'
    __mapper_args__ = {'polymorphic_identity': 'checksum'}

    checksum_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)

    sha1 = Column(String(32), index=True, unique=True, nullable=False)
    md5 = Column(String(32), index=True, unique=True, nullable=False)

    def __str__(self):
        return """    :MD5: %s
    :SHA1: %s

""" % (self.md5, self.sha1)

#INode.checksum = relationship('Checksum', secondary=inode_checksum,
#        backref='paths')


class CachedContent(INode):

    """
    This is a pointer to a local path, that may or may not contain a cached
    resource. If retrieved, the entities body is located at local_path. The 
    entity headers can be reconstructed from DB. Complete header information 
    should be mantained when a CachedContent record is created. 
    """

    __tablename__ = 'cnt'
    __mapper_args__ = {'polymorphic_identity': 'inode:cached-resource'}

    content_id = Column('id', Integer, ForeignKey('inodes.id'), primary_key=True)

    cid = Column(String(255), index=True, unique=True)
    size = Column(Integer, nullable=False)
    "The length of the raw data stream. "
    charset = Column(String(32))
    ""
    partial = Column(Boolean)
    # RFC 2616 headers
    etag = Column(String(255))
    expires = Column(DateTime)
    encodings = Column(String(255))


class Status(Node):

    """
    Made this a node so it can be annotated, and perhaps expanded in the future
    to map equivalent codes in different protocols.
    """

    __tablename__ = "status"
    __mapper_args__ = {'polymorphic_identity': 'status'}

    status_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)

    http_code = Column(Integer, unique=True)

    #ref = Column(Integer, ForeignKey('nodes.id'))
    #description = Column(Text, index=True)


class Resource(Node):

    """
    A generic resource description. Normally a subclass should be used for
    instances, choose between Invariant if the document ought not to change,
    or choose Variant to indicate a more dynamic resource.

    Generally Invariant resources are non-negotiated, but may be retrieved
    through negotiation on an associated Variant resource.
    """

    __tablename__ = 'res'
    __mapper_args__ = {'polymorphic_identity': 'resource'}

    resource_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)

    status_id = Column(ForeignKey('status.http_code'), index=True)
    status = relationship(Status, primaryjoin=status_id == Status.http_code)

    locator_id = Column(ForeignKey('ids_lctr.id'), index=True)
    location = relationship(Locator, primaryjoin=locator_id == Locator.locator_id)
    "Content-Location. , size=0"

    last_access = Column(DateTime)
    last_modified = Column(DateTime)
    last_update = Column(DateTime)

    # RFC 2616 headers
    allow = Column(String(255))

    # extension_headers  = Column(String())


fragment_variant_table = Table('fragment_variant', SqlBase.metadata,
    Column('frag_ida', Integer, ForeignKey('frags.id'), primary_key=True),
    Column('vres_idb', Integer, ForeignKey('vres.id'), primary_key=True),
#    mysql_engine='InnoDB', 
#    mysql_charset='utf8'
)

class Description(Node):

    """
    A.k.a. fragment or hash-URI.

    Denotes the ID of the entity represented by a resources. Not all
    implementations may provide such but nevertheless, the specific state is
    there and may be described. Current practice suggest each state is bound
    to a specific DOM node of the current representation. 

    XXX: Note that the actual string representation is intentionally not persisted.
        Still do this in Fragment subclass?

    Discussion
    -----------
    Ex: ../index.html is the ID and locator to a HTML document representing a
    directory, which itself might be identified by .../index.html# or even
    .../#fs:inode:123 if you want to stretch this example.
   
    Don't forget the fragment is handled entirely client-side, and in general 
    interpreted by graphical clients to correspond to an `id` attribute in an 
    XML'esque document, as per W3C standard. 
    These clients will never include that part in its request line.

    Using the fragment part, interactive clients may create unqiue URL's for 
    its various dynamic document states. Meaning each of these states is 
    treated as variant representations of an original server-rendered resource.
    Also, the URIs allow the client to record and navigate history and "bookmark
    pages", ie. annotate resources with card metadata.

    Further implementation
    -------------------------
    Fragment parts used like this usually hold one or more parameter to define 
    the current dynamic representation. This somewhat hurts the good practice of
    using proper named ID's as XML Schema and RDF N3 encourage. It also
    duplicates syntax from the query and path parameter parts, which are 
    readily supported by legions of IETF compliant libraries. 
    
    Consolidation 
    would require transparency of the client-side state on the server-side. 
    Ie., the server would have been able to render each and every fragment
    representation that the client can build up asychronously.
    """

    __tablename__ = 'frags'
    __mapper_args__ = {'polymorphic_identity': 'fragment'}

    fragment_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)

#    namespace_id = Column(Integer, ForeignKey('ns.id'))
#    namespace = relationship('Namespace', 
#            primaryjoin='namespace_id==Namespace.namespace_id')

    variants = relationship('Variant', backref='descriptions',
            secondary=fragment_variant_table)


class Comment(Description):

    __tablename__ = 'comments'
    __mapper_args__ = {'polymorphic_identity': 'fragment:comment'}

    comment_id = Column('id', Integer, ForeignKey('frags.id'), primary_key=True)

    annotated_node = Column(Integer, ForeignKey('nodes.id'))
    node = relationship(Node, 
            primaryjoin=annotated_node==Node.id)
    comment = Column(Text)


# XXX
class Predicate: pass
class SeeAlso(Predicate): pass
class SameAs(Predicate): pass
class AlternativeLink(Predicate): pass
class StylesheetLink(Predicate): pass
class Statement:
    predicate, subject, object = 'p','x','y'
class Formula:
    statements = ()
#


class Invariant(Resource):

    """
    A resource consisting of a single datastream. 
    As a general rule, Invariants should not change their semantic content,
    but may allow differation in the codec stack used.

    Ideally, a Variant can capture all parameters of an Resource
    and with that manage all possible Invariants.
    """

    __tablename__ = 'ivres'
    __mapper_args__ = {'polymorphic_identity': 'resource:invariant'}

    invariant_id = Column('id', Integer, ForeignKey('res.id'), primary_key=True)

    content_id = Column(Integer, ForeignKey('cnt.cid'), index=True)
    content = relationship(CachedContent,
            primaryjoin=content_id==CachedContent.cid)
    "A specification of the contents. "

    # RFC 2616 headers
    language = Column(String(255))
    mediatype = Column(String(255))


class Variant(Resource):

    """
    A resource the content of which comes with several variations, such as
    output format, natural language, quality indicators, and/or other features.

    Suggestions for variation include client-negotiated capabilities such as 
    ability to render specific media and other services.
    """

    __tablename__ = 'vres'
    __mapper_args__ = {'polymorphic_identity': 'resource:variant'}

    variant_id = Column('id', Integer, ForeignKey('res.id'), primary_key=True)

    # FIXME: vary information not stored
    # Structure for vary is given in RFC draft on HTTP TCN and RVSA. 

    # descriptions - many-to-may to Description.variants


class QName():
    pass#ns = ...



class Namespace(Variant):
    """
    """
    __tablename__ = 'ns'
    __mapper_args__ = {'polymorphic_identity': 'resource:variant:namespace'}

    namespace_id = Column('id', Integer, ForeignKey('vres.id'), primary_key=True)


#class BoundNamespace(ID):
#    __tablename__ = 'ns_bid'
#    __mapper_args__ = {'polymorphic_identity': 'id:namespace'}
#
#    prefix = Column(String(255), unique=True)


class Relocated(Resource):

    __tablename__ = 'relocated'
    __mapper_args__ = {'polymorphic_identity': 'resource:relocated'}

    relocated_id = Column('id', Integer, ForeignKey('res.id'), primary_key=True)

    refnew_id = Column(ForeignKey('ids_lctr.id'), index=True)
    redirect = relationship(Locator, primaryjoin=refnew_id == Locator.locator_id)

    temporary = Column(Boolean)


class Volume(Resource):

    """
    A particular storage of serialized entities, 
    as in a local filesystem tree or a blob store.
    """

    __tablename__ = 'volumes'
    __mapper_args__ = {'polymorphic_identity': 'resource:volume'}

    volume_id = Column('id', Integer, ForeignKey('res.id'), primary_key=True)

    #type_id = Column(Integer, ForeignKey('classes.id'))
    #store = relation(StorageClass, primaryjoin=type_id==StorageClass.id)

    node_id = Column(Integer, ForeignKey('nodes.id'))
    root = relationship(Node, backref='volumes',
            primaryjoin=node_id == Node.id)
    

class Bookmark(Resource):

    """
    A simple textual annotation with a sequence of tags,
    and is itself a resource.
    """

    __tablename__ = 'bm'
#    __table_args__ = {'mysql_engine': 'InnoDB', 'mysql_charset': 'utf8'}
    __mapper_args__ = {'polymorphic_identity': 'resource:bookmark'}

    bookmark_id = Column('id', Integer, ForeignKey('res.id'), primary_key=True)

    ref_id = Column(Integer, ForeignKey('ids_lctr.id'))
    ref = relationship(Locator, primaryjoin=Locator.locator_id==ref_id)

    extended = Column(Text(65535))#, index=True)
    "Textual annotation of the referenced resource. "
    public = Column(Boolean(), index=True)
    "Private or public. "
    tags = Column(String(255))
    "Comma-separated list of tags. "


workset_locator_table = Table('workset_locator', SqlBase.metadata,
    Column('left_id', Integer, ForeignKey('ws.id'), primary_key=True),
    Column('right_id', Integer, ForeignKey('ids_lctr.id'), primary_key=True),
#    mysql_engine='InnoDB', 
#    mysql_charset='utf8'
)


class Workset(Resource):

    """
    One or more locators together form a new resource that should represent
    the merged subtrees.
    """

    __tablename__ = 'ws'
#    __table_args__ = {'mysql_engine': 'InnoDB', 'mysql_charset': 'utf8'}
    __mapper_args__ = {'polymorphic_identity': 'resource:workset'}

    id = Column(Integer, ForeignKey('res.id'), primary_key=True)

    refs = relationship(Locator, secondary=workset_locator_table)


token_locator_table = Table('token_locator', SqlBase.metadata,
    Column('left_id', Integer, ForeignKey('stk.id'), primary_key=True),
    Column('right_id', Integer, ForeignKey('ids_lctr.id'), primary_key=True),
#    mysql_engine='InnoDB', 
#    mysql_charset='utf8'
)


class Token(Node):

    __tablename__ = 'stk'
#    __table_args__ = {'mysql_engine': 'InnoDB', 'mysql_charset': 'utf8'}
    __mapper_args__ = {'polymorphic_identity': 'meta:security-token'}

    id = Column(Integer, ForeignKey('nodes.id'), primary_key=True)

    value = Column(Text(65535))#, index=True, nullable=True)
    refs = relationship(Locator, secondary=token_locator_table)


def get_session(dbref, initialize=False):
    engine = create_engine(dbref, encoding='utf8')
    if initialize:
        SqlBase.metadata.create_all(engine)  # issue DDL create 
        print 'Updated schema'
    session = sessionmaker(bind=engine)()
    return session
#   dbref='mysql://scrow-user:p98wa7txp9zx@sam/scrow'
#   engine = create_engine(dbref, encoding='utf8', convert_unicode=False)
#    engine = create_engine('sqlite:///test.sqlite')#, echo=True)

    #dbref = 'mysql://root:MassRootSql@robin/taxus'
    #dbref = 'mysql://root:MassRootSql@robin/taxus_o'


class Taxus(Cmd):

    NAME = os.path.splitext(os.path.basename(__file__))[0]

    DB_PATH = os.path.expanduser('~/.cllct/db.sqlite')
    DEFAULT_DB = "sqlite:///%s" % DB_PATH

    DEFAULT_CONFIG_KEY = NAME

    TRANSIENT_OPTS = Cmd.TRANSIENT_OPTS + ['query', 'init_database']
    DEFAULT_ACTION = 'query'

    @classmethod
    def get_opts(klass):
        return (
                (('-d', '--dbref'), { 'metavar':'URI', 
                    'default': klass.DEFAULT_DB, 
                    'dest': 'dbref',
                    'help': "A URI formatted relational DB access description "
                        "(SQLAlchemy implementation). Ex: "
                        " `sqlite:///taxus.sqlite`,"
                        " `mysql://taxus-user@localhost/taxus`. "
                        "The default value (%default) may be overwritten by configuration "
                        "and/or command line option. " }),

                (('-q', '--query'), {'action':'callback', 
                    'callback_args': ('query',),
                    'callback': libcmd.optparse_override_handler,
                    'dest': 'command',
                    'help': "TODO" }),
#'-X', 
                (('--init-database',), {
                    'action': 'callback', 
                    'callback_args': ('init_database',),
                    'dest': 'command', 
                    'callback': libcmd.optparse_override_handler,
                    'help': "TODO" }),

                (('--init-host',), {
                    'action': 'callback', 
                    'callback_args': ('init_host',),
                    'dest': 'command', 
                    'callback': libcmd.optparse_override_handler,
                    'help': "TODO" }),
            )

    @staticmethod
    def get_options():
        return Cmd.get_opts() + Taxus.get_opts()

    # Main handler config

    main_handlers = [
            #'main_config',
            'main_session',
            'main_run_actions'
        ]

    def main_session(self, opts, args):
    
        # Initialize session, 'default' may have ben initialized already
        self.session = SessionMixin.get_instance('default', opts.dbref)#optdict.get('dbref'))
        if not self.session and not opts.command.startswith('init'):
            err("Cannot get storage session, perhaps use --init-database? ")
            sys.exit(1)

        try:
            self.host = self.host_find([], opts)
        except Exception, e:
            self.host = None
            err("Query failure: %s", e)
        if not self.host and not opts.command.startswith('init'):
            err("Unknown host, perhaps use --init-host? ")
            sys.exit(1)

    def init_config_defaults(self, dbref=None, **opts):
        pass

    # Extra commands
    def init_host(self, options=None):
        """
        Tie Host to current system. Initialize Host if needed. 
        """
        hostnamestr = current_hostname(True, options.interactive)
        assert hostnamestr
        hostname = self.hostname_find([hostnamestr], options)
        if not hostname:
            hostname = Name(name=hostnamestr,
                    date_added=datetime.now())
            hostname.commit()
        assert hostname
        host = self.host_find([hostname], options)
        if not host:
            host = Host(hostname=hostname,
                    date_added=datetime.now())
            host.commit()
        assert host
        print "Initialized host:"
        print taxus_out.IFormatted(host).__str__()
        return host

    def init_database(self, options=None):
        dbref = options.dbref
        print "Applying SQL DDL to DB %s " % dbref
        self.session = get_session(dbref, initialize=True)
        return self.session

    def hostname_find(self, args, opts):
        if not args:
            hostnamestr = current_hostname()
        else:
            hostnamestr = args.pop(0)
        if not hostnamestr:
            return
        try:
            name = self.session\
                    .query(Name)\
                    .filter(Name.name == hostnamestr).one()
        except NoResultFound, e:
            name = None
        return name

    def host_find(self, args, opts):
        """
        Identify given or current host.
        """
        name = None
        if args:
            name = args.pop(0)
        if not isinstance(name, Name):
            name = self.hostname_find([name], opts)
        if not name:
            name = self.hostname_find(args, opts)
        if not name and not opts.command.startswith('init'):
            err("Cannot find hostname, %s", args)
            return
        node = Node
        try:
            node = self.session.query(Host)\
                    .filter(Host.hostname == name).one()
        except NoResultFound, e:
            return
        return node

    def find_inode(self, path):
        inode = INode(local_path=path)
        inode.host = self.find_host()
        return inode

    def query(self, *args, **opts):
        print 'TODO: query:',args
        q = self.session.query(Node)
        return ResultSet(q, q.all())

    subcmd_aliases = {
            'rm': 'remove',
            'upd': 'update',
        }

    def node(self, *args, **opts):
        subcmd = args[0]
        while subcmd in subcmd_aliases:
            subcmd = subcmd_aliases[subcmd]
        assert subcmd in ('add', 'update', 'remove'), subcmd
        getattr(self, subcmd)(args[1:], **opts)
       
    def node_add(self, name, **opts):
        "Don't call this directly from CL. "
        s = get_session(opts.get('dbref'))
        node = Node(name=name, 
                date_added=datetime.now())
        s.add(node)
        return node

    def node_remove(self, *args, **opts):
        s = get_session(opts.get('dbref'))
        pass # TODO: node rm
        return
        node = None#s.query(Node).
        node.deleted = True
        node.date_deleted = datetime.now()
        s.add(node)
        s.commit()
        return node

    def node_update(self, *args, **opts):
        pass # TODO: node update

#    def namespace_add(self, name, prefix, uri, **opts):
#        uriref = Locator(ref=uri)
#        node = Namespace(name=name, prefix=prefix, locator=uriref,
#                date_added=datetime.now())
#        s.add(node)
#        s.commit()
#        return node

#    def description_new(self, name, ns_uri):
#        Description(name=name, 
#                date_added=datetime.now())

    def comment_new(self, name, comment, ns, node):
        #NS = self.
        node = Comment( name=name,
                #namespace=NS,
                annotated_node=node,
                comment=comment,
                date_added=datetime.now())
        return node

if __name__ == '__main__':
    app = Taxus()
    app.main()



# Testing

def test_tree(s):

    now = datetime.now()

    n = Node(name='/', date_added=now)
    s.add(n), s.commit()

    n = Node(space_id=1, name='test1', date_added=now)
    s.add(n), s.commit()
    n = Node(space_id=2, name='test1.1', date_added=now)
    s.add(n), s.commit()

    now = datetime.now()
    r = Resource(space_id=1, name='Resource 1 (1.1)', date_added=now)
    s.add(r), s.commit()

    now = datetime.now()
    r = Resource(space_id=4, name='Resource 2 (1.1.1)', date_added=now)
    s.add(r), s.commit()

def test_annotate(s):

    now = datetime.now()
    ref1 = Locator(name='Local Web Site Reference 1', ref='http://localhost/', date_added=now)
    s.add(ref1), s.commit()

    rs1 = Resource(name='Local Web Site', location=ref1, date_added=now)
    s.add(rs1), s.commit()

    now = datetime.now()
    bm = Bookmark(name='My bookmark', ref=ref1, date_added=now)
    s.add(bm), s.commit()

    now = datetime.now()
    ref2 = Locator(name='Internet Web Site', ref='http://example.net/', date_added=now)
    s.add(ref2), s.commit()

    now = datetime.now()
    bm = Bookmark(name='My bookmark 2', ref=ref2, date_added=now)#, size=1230)
    s.add(bm), s.commit()


def test_variants(s):

    now = datetime.now()

    v = Invariant(name='test')

def test_print(s):

    #print s.query(Locator, Resource).join('location').filter_by(ref='http://example.net/').all()
    print 'all', s.query(Resource, Locator).join('location').all()
    print
    print 'localhost', s.query(Resource, Locator).join('location').filter(Locator.ref=='http://localhost/').all()
    print 'localhost', s.query(Resource, Locator).join('location').filter_by(ref='http://localhost/').all()
    print

    print
    print 'Printing nodes'
    for n in s.query(Node).all():
        n.record_format = 'format2'
        print str(n), [n.id for n in n.children]

    print
    print 'Printing resources'
    for r in list(s.query(Resource).all()):
        print r

