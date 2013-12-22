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
    Provide lookup on numeric ID, name (non-unique) and standard dates.
    """

    zope.interface.implements(iface.INode)

    __tablename__ = 'nodes'
    node_id = Column('id', Integer, primary_key=True)

    ntype = Column('ntype', String(50), nullable=False)
    __mapper_args__ = {'polymorphic_on': ntype}
    
    name = Column(String(255), nullable=True)
    #name = Column(String(255), nullable=False, unique=True)
    
    #space_id = Column(Integer, ForeignKey('nodes.id'))
    #space = relationship('Node', backref='children', remote_side='Node.id')
    
    date_added = Column(DateTime, index=True, nullable=False)
    deleted = Column(Boolean, index=True, default=False)
    date_deleted = Column(DateTime)


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
    """

    zope.interface.implements(iface.IID)

    __tablename__ = 'ids_name'
    name_id = Column('id', Integer, primary_key=True)

    date_added = Column(DateTime, index=True, nullable=False)
    deleted = Column(Boolean, index=True, default=False)
    date_deleted = Column(DateTime)

    name = Column(String(255), index=True, unique=True)

    def __str__(self):
        return "<%s %r>" % (lib.cn(self), self.name)

    def __repr__(self):
        return "<Name %r>" % self.name


class Tag(Name):

    """
    Tags primarily constitute a name unique within some namespace.
    They may be used as types or as instance identifiers.
    """
    zope.interface.implements(iface.IID)

    __tablename__ = 'ids_tag'
    __mapper_args__ = {'polymorphic_identity': 'tag'}

    tag_id = Column('id', Integer, ForeignKey('ids_name.id'), primary_key=True)

    name = Column(String(255), unique=True, nullable=True)
    #sid = Column(String(255), nullable=True)
    # XXX: perhaps add separate table for Tag.namespace attribute
    namespaces = relationship('Namespace', secondary=tag_namespace_table)
        backref='tags')



