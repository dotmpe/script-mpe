from datetime import datetime

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


class Bookmark(web.Resource):#SqlBase, CardMixin, ORMMixin):#core.Node):

    """
    A textual annotation with a short and long descriptive label,
    a sequence of tags, the regular set of dates,
    """

    __tablename__ = 'bm'
    __mapper_args__ = {'polymorphic_identity': 'resource:bookmark'}
    bm_id = Column('id', Integer, ForeignKey('res.id'), primary_key=True)

    #ref_id = Column(Integer, ForeignKey('ids_lctr.id'))
    #ref = relationship(net.Locator, primaryjoin=net.Locator.lctr_id==ref_id)

    name = Column(String(255))

    extended = Column(Text)#, index=True)
    "Textual annotation of the referenced resource. "
    public = Column(Boolean(), index=True)
    "Private or public. "
    tags = Column(Text)# XXX: text param NA for postgres (10240))
    "Comma-separated list of all tags. "

    @classmethod
    def keys(klass):
        return web.Resource.keys() + 'name extended public tags'.split(' ')

    def to_dict(self):
        d = dict(href=self.location.href())
        k = self.__class__.keys() + 'deleted date_added date_deleted date_updated'.split(' ')
        for p in k:
            d[p] = getattr(self, p)
        d['tags'] = d['tags'].split(', ')
        return d

    def update_from(self, **doc):
        data = self.__class__.dict_from_doc(**doc)
        updated = False
        for k in data:
            if getattr(self, k) != data[k]:
                setattr(self, k, data[k])
                updated = True
        return updated

    @classmethod
    def dict_from_doc(klass, **doc):
        if not doc['location']:
            raise Error("TODO")
        opts = dict(location=doc['location'])
        for k in klass.keys():
            if k in doc:
                opts[k] = doc[k]
            if k == 'tags':
                opts[k] = ", ".join(opts[k])
            if isinstance(opts[k], datetime):
                opts[k] = datetime.strptime(opts[k], ISO_8601_DATETIME)
        return opts

    @classmethod
    def from_dict(klass, **doc):
        opts = klass.dict_from_doc(**doc)
        return klass( **opts )



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





models = [ Relocated, Volume, Bookmark, Workset ]


