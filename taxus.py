"""
Taxus ORM (SQL) model.

All objects inherit from Node. Each object type is has its own table. Stored
objects have records in `nodes` and all other 'parent' tables (references via
foreign-keys). The `nodes` table stores the objects type, meaning there can be 
only one type for a node record at any time.

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
           * ntype          |                                 |  
           * size           |           ^           ^         |
           * cum_size       |           |           |         |
                            |           |           |         | 
        A             V     |           |           |         | 
        |             |     |           |           |         | 
     CachedContent    |    Resource     |           |         |    
      * cid           |     * status ---/           |         |        
      * size          |     * location -------------/         | 
      * charset       |     * last/a/u-time         |         |  
      * partial       |     * allow                 |         | 
      * expires       |                             |         |
      * etag          |     A                       |         |
                      |     |                       |         | 
      ^               /-----|-----------------------/   /--> Description
      |               |     |                       |   |     * label
      |  Invariant ---|-----'---- Variant           |   |      
      \-- * content   |     |      * vary           |   |    Predicate        
          * mediatype |     |      * description ---|---/               
          * languages |     |                       |          SeeAlso          
                      |     |                       |          SameAs 
                      A     '---- Relocated         |              
               Checksum     |      * new_location --/        Statement    
                * sha1      |      * temporary                * subject    
                * md5       |                                 * predicate   
                            '---- Volume                      * object     
                            |                                                   
                            '---- Bookmark                   Formula         
                                                              * statements



This schema will make node become large very quickly. Especially as various
metadata relations between Nodes are recorded in Statements.
In addition, Statements will probably rather refer to Fragment nodes rather than 
Resource nodes, adding another layer of similar but distinct nodes.

The Description column in the diagram is there to get an idea, while most such
data should be stored a suitable triple store.

"""
from datetime import datetime

from sqlalchemy import Column, Integer, String, Boolean, Text, \
    ForeignKey, Table, Index, DateTime, \
    create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship, backref, sessionmaker

#from debug import PrintedRecordMixin 


SqlBase = declarative_base()

DEFAULT_STORE = 'sqlite:////'

class Session(object):

    sessions = {}

    @staticmethod
    def get_instance(name='default', dbref=DEFAULT_STORE):
        if name not in Session.sessions:
            Session.sessions[name] = initialize(dbref)
        return Session.sessions[name]

    # 
    key_names = ['id']

    def key(self):
        key = {}
        for a in self.key_names:
            key[a] = getattr(self, a)
        return key

    def commit(self):
        session = Session.get_instance()
        session.add(self)
        session.commit()

    def fetch(self):
        session = Session.get_instance()
        keydict = self.key()
        return session.query(self.__class__).filter(**keydict).one()
        
    def exists(self):
        return self.fetch() != None 


class Node(SqlBase, Session):#, PrintedRecordMixin):

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


class INode(Node):

    __tablename__ = 'inodes'
    __mapper_args__ = {'polymorphic_identity': 'inode'}

    inode_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)

    type = Column(Integer, index=True, unique=True)
    local_path = Column(String(255), index=True, unique=True)


# mapping table for Checksum [1-*] Locator
locator_checksum = Table('locator_checksum', SqlBase.metadata,
    Column('locator_ida', ForeignKey('lctrs.id')),
    Column('chk_idb', ForeignKey('chks.id'))
)
# mapping table for Checksum [1-*] INode 
inode_checksum = Table('inode_checksum', SqlBase.metadata,
    Column('inode_ida', ForeignKey(INode.inode_id)),
    Column('chk_idb', ForeignKey('chks.id'))
)


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

INode.checksum = relationship('Checksum', secondary=inode_checksum,
        backref='paths')


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


class Locator(Node):

    """
    A global identifier for retrieval of remote content.
    """

    __tablename__ = 'lctrs'
    __mapper_args__ = {'polymorphic_identity': 'reference'}

    locator_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)

    ref = Column(String(255), index=True, unique=True)
   
    checksums = relationship('Checksum', secondary=locator_checksum,
        backref='locator')


class Status(Node):

    __tablename__ = "status"
    __mapper_args__ = {'polymorphic_identity': 'status'}

    status_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)

    nr = Column(Integer, unique=True)

    #ref = Column(Integer, ForeignKey('nodes.id'))
    #description = Column(Text, index=True)


class Resource(Node):

    """
    A generic resource.
    """

    __tablename__ = 'res'
    __mapper_args__ = {'polymorphic_identity': 'resource'}

    resource_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)

    status_id = Column(ForeignKey('status.nr'), index=True)
    status = relationship(Status, primaryjoin=status_id == Status.nr)

    locator_id = Column(ForeignKey('lctrs.id'), index=True)
    location = relationship(Locator, primaryjoin=locator_id == Locator.locator_id)
    "Content-Location. , size=0"

    last_access = Column(DateTime)
    last_modified = Column(DateTime)
    last_update = Column(DateTime)

    # RFC 2616 headers
    allow = Column(String(255))

    # extension_headers  = Column(String())


class Description(Node):

    """
    A.k.a. fragment or hash-URI.

    Denotes a (or the) specific resource usually associated with a web URL. Ie.
    index.html is the locator to a HTML document representing a directory, while 
    index.html# may refer to a specific instance, e.g. a list of directory entries
    or in this case an some document view such as a DOM. 
    
    In a similar way `named fragments` may refer to parts of a document. 
    """

    __tablename__ = 'frag'
    __mapper_args__ = {'polymorphic_identity': 'fragment'}

    fragment_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)


class Invariant(Resource):

    """
    A resource consisting of a single datastream.
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
    output format, natural language or quality indicators.
    """

    __tablename__ = 'vres'
    __mapper_args__ = {'polymorphic_identity': 'resource:variant'}

    variant_id = Column('id', Integer, ForeignKey('res.id'), primary_key=True)

    # vary #features
     
    #resources = relationship(Locator, primaryjoin=ivres_id==Invariant.id)


#locators_resource = Table('locators_resource', SqlBase.metadata,
#    Column('lctr_ida', Integer, ForeignKey('lctr.id')),
#    Column('res_idb', Integer, ForeignKey('res.id')),
#)
#Resource.locators = relationship(Locator, secondary=locators_resource)


#relocated = Table('relocated_resources', SqlBase.metadata,
#    Column('', ForeignKey('')),
#    Column('', ForeignKey('')),
#)

class Relocated(Resource):

    __tablename__ = 'relocated'
    __mapper_args__ = {'polymorphic_identity': 'resource:relocated'}

    relocated_id = Column('id', Integer, ForeignKey('res.id'), primary_key=True)

    refnew_id = Column(ForeignKey('lctrs.id'), index=True)
    new_location = relationship(Locator, primaryjoin=refnew_id == Locator.locator_id)

    temporary = Column(Boolean)


class Volume(Resource):

    """
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

    ref_id = Column(Integer, ForeignKey('nodes.id'))
    ref = relationship(Locator, primaryjoin=Locator.id==ref_id)

    extended = Column(Text(65535))#, index=True)
    "Textual annotation of the referenced resource. "
    public = Column(Boolean(), index=True)
    "Private or public. "
    tags = Column(String(255))
    "Comma-separated list of tags. "


workset_locator_table = Table('workset_locator', SqlBase.metadata,
    Column('left_id', Integer, ForeignKey('ws.id'), primary_key=True),
    Column('right_id', Integer, ForeignKey('lctrs.id'), primary_key=True),
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
    Column('right_id', Integer, ForeignKey('lctrs.id'), primary_key=True),
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


def initialize(dbref, create=False):
    engine = create_engine(dbref, encoding='utf8')
    if create:
        SqlBase.metadata.create_all(engine)  # issue DDL create 
        print 'Updated schema'
    session = sessionmaker(bind=engine)()
    return session



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


if __name__ == '__main__':
#   dbref='mysql://scrow-user:p98wa7txp9zx@sam/scrow'
#   engine = create_engine(dbref, encoding='utf8', convert_unicode=False)
#    engine = create_engine('sqlite:///test.sqlite')#, echo=True)

    #dbref = 'mysql://root:MassRootSql@robin/taxus'
    #s = initialize(dbref)
    dbref = 'mysql://root:MassRootSql@robin/taxus_o'
    s = initialize(dbref, create=True)
    #test_tree(s)
    #test_annotate(s)
    #test_print(s)

