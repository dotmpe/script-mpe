import zope.interface
from sqlalchemy import Column, Integer, String, Boolean, Text, \
    ForeignKey, Table, Index, DateTime
from sqlalchemy.orm import relationship, backref

from .init import SqlBase
from .util import ORMMixin
from .mixin import CardMixin
from . import net
from . import web



class Localname(net.Locator):

    __tablename__ = 'ids_lctr_localname'
    __mapper_args__ = {'polymorphic_identity': 'id:locator:localname'}

    localname_id = Column('id', Integer, ForeignKey('ids_lctr.id'), primary_key=True)

    name = Column(String(255), unique=True, nullable=False)


class Namespace(web.Variant):
    """
    An resource with a set of unique names, each of which is resolvable.

    The namespace record serves two purposes. The primary is to reduce overhead
    on the locator index. The seconary is to group resources, and assign schema
    to the groups. Because

    The namespace is a variant resource, ie. it can be represented in different
    formats.

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

# str_format = Column(String(255))

    # tags = *Tag; see relationship in tag_namespace_table
    # FIXME: where does the prefix go

#class BoundNamespace(ID):
#    __tablename__ = 'ns_bid'
#    __mapper_args__ = {'polymorphic_identity': 'id:namespace'}
#
#    prefix = Column(String(255), unique=True)


models = [ Namespace, Localname ]

