import zope.interface
from sqlalchemy import Column, Integer, String, Boolean, Text, \
    ForeignKey, Table, Index, DateTime
from sqlalchemy.orm import relationship, backref

from .init import SqlBase
from .util import ORMMixin
from .mixin import CardMixin
from . import core
from . import net
from . import web


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


class Volume(core.Scheme):

    """
    A packaged collection of resources. A particular storage of serialized
    entities, as in a local filesystem (disk partition) or a blob store.

    Volumes can be nested. TODO: express some types of nesting, ie. SCM, TAR,
    other compositions.

    Each volume may have its own local name access method, or not?

    E.g. consider ``volume-16-4-boreas-brix:htdocs/main.rst`` or
    ``htdocs-16-4-boreas-brix:main``. Both identify the index for Htdocs.
    """

    __tablename__ = 'volumes'
    __mapper_args__ = {'polymorphic_identity': 'volume-name'}

    volume_id = Column('id', Integer, ForeignKey('schemes.id'), primary_key=True)

    #type_id = Column(Integer, ForeignKey('classes.id'))
    #store = relation(StorageClass, primaryjoin=type_id==StorageClass.id)

    root_node_id = Column(Integer, ForeignKey('nodes.id'))
    root = relationship(core.Node, backref='volumes',
            primaryjoin=root_node_id == core.Node.node_id)


class Bookmark(SqlBase, CardMixin, ORMMixin):#core.Node):

    """
    A textual annotation with a short and long descriptive label,
    a sequence of tags, the regular set of dates,
    """

    __tablename__ = 'bm'
    #__table_args__ = {'mysql_engine': 'InnoDB', 'mysql_charset': 'utf8'}
    #__mapper_args__ = {'polymorphic_identity': 'bookmark'}
    #bm_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)
    bm_id = Column('id', Integer, primary_key=True)

    ref_id = Column(Integer, ForeignKey('ids_lctr.id'))
    ref = relationship(net.Locator, primaryjoin=net.Locator.lctr_id==ref_id)

    #extended = Column(Text(65535))#, index=True)
    extended = Column(Text)#, index=True)
    "Textual annotation of the referenced resource. "
    public = Column(Boolean(), index=True)
    "Private or public. "
    tags = Column(Text)# XXX: text param NA for postgres (10240))
    "Comma-separated list of all tags. "


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



class Token(SqlBase, ORMMixin):

    """
    A large-value variant on Tag, perhaps should make this a typetree.
    """

    __tablename__ = 'stk'
    __mapper_args__ = {'polymorphic_identity': 'meta:security-token'}

    token_id = Column('id', Integer, primary_key=True)

    value = Column(Text, index=True, nullable=True, unique=True)
    refs = relationship(net.Locator, secondary=token_locator_table)


models = [ Namespace, Relocated, Volume, Bookmark, Workset, Token ]


