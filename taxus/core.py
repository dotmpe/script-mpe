import zope.interface
from sqlalchemy import Column, Integer, String, Boolean, Text, \
    ForeignKey, Table, Index, DateTime
#from sqlalchemy.orm.exc import NoResultFound
from sqlalchemy.orm import relationship, backref

import iface
from init import SqlBase
from util import SessionMixin

import lib
import log




# mapping table for Node *-* Node
nodes_nodes = Table('nodes_nodes', SqlBase.metadata,
    Column('nodes_ida', Integer, ForeignKey('nodes.id'), nullable=False),
    Column('nodes_idb', Integer, ForeignKey('nodes.id'), nullable=False),
    Column('nodes_idc', Integer, ForeignKey('nodes.id'))
)




class Node(SqlBase, SessionMixin):

    """
    The basic element in the data structure.
    Should name be unique? It is now, and title (on subclasses)?

    These can be seen as local IDs or names, in contrast with
    IDs and Names which are global (and unique...).
    """

    zope.interface.implements(iface.INode)

    __tablename__ = 'nodes'
    node_id = Column('id', Integer, primary_key=True)

    ntype = Column('ntype', String(50), nullable=False)
    __mapper_args__ = {'polymorphic_on': ntype}
    
    name = Column(String(255), nullable=True)
    
    #space_id = Column(Integer, ForeignKey('nodes.id'))
    #space = relationship('Node', backref='children', remote_side='Node.id')
    
    date_added = Column(DateTime, index=True, nullable=False)
    deleted = Column(Boolean, index=True, default=False)
    date_deleted = Column(DateTime)


class AnnotatedNode(Node):

    """
    Stand alone or base type for annotated nodes.

    To simply annotate a random node, use Comment instead as that is ented on 
    a particular resource. An annotation in contrast is a blank labelled node
    by default.
    """
    
    __tablename__ = 'anodes'
    __mapper_args__ = {'polymorphic_identity': 'anode'}

    annotation_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)

    title = Column(String(255))
    description = Column(Text)


class ID(SqlBase, SessionMixin):

    """
    A global identifier.
    """

    zope.interface.implements(iface.IID)

    __tablename__ = 'ids'
    id_id = Column('id', Integer, primary_key=True)

    date_added = Column(DateTime, index=True, nullable=False)
    deleted = Column(Boolean, index=True, default=False)
    date_deleted = Column(DateTime)


class Name(SqlBase, SessionMixin):

    """
    A global identifier name.

    These are used as the interface to Node subclasses,
    IOW. to map internal data to and from external resources.
    """

    zope.interface.implements(iface.IID)

    __tablename__ = 'ids_name'
    name_id = Column('id', Integer, primary_key=True)

    date_added = Column(DateTime, index=True, nullable=False)
    deleted = Column(Boolean, index=True, default=False)
    date_deleted = Column(DateTime)

    name = Column(String(255), index=True, unique=True)

    def __str__(self):
        return "%s at %s having %r" % (lib.cn(self), self.taxus_id(), self.name)

    def __repr__(self):
        return "<%s %s %r>" % (lib.cn(self), hex(id(self)), self.name)


class Tag(Node):

    """
    deprecated: use node instead
    """
    zope.interface.implements(iface.IID)

    __tablename__ = 'ids_tag'
    __mapper_args__ = {'polymorphic_identity': 'tag'}

    tag_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)

    date_added = Column(DateTime, index=True, nullable=False)
    deleted = Column(Boolean, index=True, default=False)
    date_deleted = Column(DateTime)

    name = Column(String(255), unique=True, nullable=True)
    #sid = Column(String(255), nullable=True)




