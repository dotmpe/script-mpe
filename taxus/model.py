from datetime import datetime
import hashlib

import zope.interface
from sqlalchemy import Column, Integer, String, Boolean, Text, \
    ForeignKey, Table, Index, DateTime, or_
from sqlalchemy.orm import relationship, backref

from script_mpe.couch import bookmark

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

    name = Column(String(255))

    extended = Column(Text)#, index=True)
    "Textual annotation of the referenced resource. "
    public = Column(Boolean(), index=True)
    "Private or public. "
    tags = Column(Text)# XXX: text param NA for postgres (10240))
    "Comma-separated list of all tags. "

    @staticmethod
    def keyid(*a):
        "Return Couch doc key"
        return hashlib.sha256(*a).hexdigest()

    @staticmethod
    def key(o):
        "Return Couch doc key for object"
        # TODO: deal with URN's later
        return Bookmark.keyid(o.href)

    @classmethod
    def unique_tags(klass, NAME, g, ctx):
        tags = set()
        q = ctx.sa_session.query(Bookmark.tags)
        filters = ()
        for name in NAME:
            if g.exact_match:
                filters += or_(
                            Bookmark.tags.like('%%, %s, %%' % name),
                            # TODO: insert spaces to be able to like-match start/end/sa:
                            Bookmark.tags.like(' %s, %%' % name),
                            Bookmark.tags.like('%%, %s ' % name),
                            Bookmark.tags.like(' %s ' % name),
                        ),
            else:
                filters += ( Bookmark.tags.like('%%%s%%' % name), )
        if filters:
            q = q.filter(*filters).distinct()
        rs = q.all()
        for r in rs:
            assert isinstance(r.tags, basestring), r.tags
            tags = tags.union(r.tags.split(', '))
        return tags

    @classmethod
    def keys(klass):
        "Return SQL columns"
        return web.Resource.keys() + 'name extended public tags'.split(' ')

    def to_doc(self):
        "Turn record into Couch doc"
        d = self.to_dict()
        d.update(dict(
            type='bookmark',
            id=Bookmark.key(self)
        ))
        return bookmark.Bookmark(**d)

    def to_struct(self, d={}):
        "Turn into struct for JSON or Couch doc use"
        d = web.Resource.to_dict(self, d=d)
        assert isinstance(d['tags'], basestring), d['tags']
        d.update(dict(
            location=self.location.to_struct(),
            tags_list=d['tags'].split(', ')
        ))
        return d

    def to_dict(self, d={}):
        "Turn into flat struct with simple and date/time types only, for JSON or Couch doc use"
        d = web.Resource.to_dict(self, d=d)
        assert isinstance(d['tags'], basestring), d['tags']
        d.update(dict(
            href=self.location.href(),
            tags_list=d['tags'].split(', ')
        ))
        return d

    def update_from(self, *docs, **kwds):
        updated = web.Resource.update_from(self, *docs, **kwds)
        if updated:
            assert isinstance(self.tags, basestring), self.tags
            # self.tags = ', '.join( self.tags )
        return updated


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
