import zope.interface
from sqlalchemy import Column, Integer, String, Boolean, Text, \
    ForeignKey, Table, Index, DateTime
from sqlalchemy.orm import relationship, backref

from init import SqlBase
from util import SessionMixin
import core
import net
import web


class QName():
    pass#ns = ...


class Namespace(web.Variant):
    """
    A set of unique names. 

    The namespace at a minimum has an system identifier,
    which may refer to one or more global identifiers.

    XXX: A collection of anything? What.
    See Tag, a namespace constituting distinct tag types. 
    But also code, objects.
    XXX: there is no mux/demux (yet) so subclassing variant does not mean much, but anyway.
    XXX: Being a variant, the canonical URL, may be used as identifier, may be
    stored at related Invariant record. some consideration needs to go there
    """
    __tablename__ = 'ns'
    __mapper_args__ = {'polymorphic_identity': 'resource:variant:namespace'}

    namespace_id = Column('id', Integer, ForeignKey('vres.id'), primary_key=True)

    # tags = *Tag; see relationship in tag_namespace_table

    # FIXME: where does the prefix go

#class BoundNamespace(ID):
#    __tablename__ = 'ns_bid'
#    __mapper_args__ = {'polymorphic_identity': 'id:namespace'}
#
#    prefix = Column(String(255), unique=True)


class Relocated(web.Resource):

    __tablename__ = 'relocated'
    __mapper_args__ = {'polymorphic_identity': 'resource:relocated'}

    relocated_id = Column('id', Integer, ForeignKey('res.id'), primary_key=True)

    refnew_id = Column(ForeignKey('ids_lctr.id'), index=True)
    redirect = relationship(net.Locator, primaryjoin=refnew_id == net.Locator.lctr_id)

    temporary = Column(Boolean)


class Volume(web.Resource):

    # XXX: merge with res.Volume

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
    root = relationship(core.Node, backref='volumes',
            primaryjoin=node_id == core.Node.node_id)


class Bookmark(web.Resource):

    """
    A textual annotation with a short and long descriptive label,
    a sequence of tags, the regular set of dates, 
    and is itself a resource.
    """

    __tablename__ = 'bm'
#    __table_args__ = {'mysql_engine': 'InnoDB', 'mysql_charset': 'utf8'}
    __mapper_args__ = {'polymorphic_identity': 'resource:bookmark'}

    bookmark_id = Column('id', Integer, ForeignKey('res.id'), primary_key=True)

    ref_id = Column(Integer, ForeignKey('ids_lctr.id'))
    ref = relationship(net.Locator, primaryjoin=net.Locator.lctr_id==ref_id)

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


class Workset(web.Resource):

    """
    One or more locators together form a new resource that should represent
    the merged subtrees.
    """

    __tablename__ = 'ws'
#    __table_args__ = {'mysql_engine': 'InnoDB', 'mysql_charset': 'utf8'}
    __mapper_args__ = {'polymorphic_identity': 'resource:workset'}

    ws_id = Column('id', Integer, ForeignKey('res.id'), primary_key=True)

    refs = relationship(net.Locator, secondary=workset_locator_table)


token_locator_table = Table('token_locator', SqlBase.metadata,
    Column('left_id', Integer, ForeignKey('stk.id'), primary_key=True),
    Column('right_id', Integer, ForeignKey('ids_lctr.id'), primary_key=True),
)



class Token(SqlBase, SessionMixin):

    """
    A large-value variant on Tag, perhaps should make this a typetree.
    """

    __tablename__ = 'stk'
    __mapper_args__ = {'polymorphic_identity': 'meta:security-token'}

    token_id = Column('id', Integer, primary_key=True)

    value = Column(Text(65535), index=True, nullable=True, unique=True)
    refs = relationship(net.Locator, secondary=token_locator_table)

