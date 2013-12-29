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
        return "%s at %s having %r" % (lib.cn(self), self.taxus_id(), self.name)

    def __repr__(self):
        return "<%s %s %r>" % (lib.cn(self), hex(id(self)), self.name)


class Tag(Name):

    """
    Tags primarily constitute a name unique within some namespace.
    They may be used as types or as instance identifiers.
    """
    zope.interface.implements(iface.IID)

    __tablename__ = 'ids_tag'
    __mapper_args__ = {'polymorphic_identity': 'tag'}

    tag_id = Column('id', Integer, ForeignKey('ids_name.id'), primary_key=True)

    #name = Column(String(255), unique=True, nullable=True)
    #sid = Column(String(255), nullable=True)
    # XXX: perhaps add separate table for Tag.namespace attribute
#    namespaces = relationship('Namespace', secondary=tag_namespace_table,
#        backref='tags')


class Topic(Tag):
    """
    A topic describes a subject; a theme, issue or matter, regarding something
    else. 
    XXX: It is the first of a level abstraction for other elementary types like
    inodes or document elements.
    For now, it is a succinct name on the Tag supertype, with an additional
    Text field for further specification.
    
    XXX: a basic type indicator to toggle between a thing or an idea.
    Names are given in singular form, a text field codes the plural for UI use.
    """
    __tablename__ = 'ids_topic'
    __mapper_args__ = {'polymorphic_identity': 'topic'}
    topic_id = Column('id', Integer, ForeignKey('ids_tag.id'))

    about_id = Column(Integer, ForeignKey('nodes.id'))

    explanation = Column(Text)
    thing = Column(Boolean)
    plural = Column(String)



doc_root_element_table = Table('doc_root_element', SqlBase.metadata,
    Column('inode_id', Integer, ForeignKey('inodes.id'), primary_key=True),
    Column('lctr_id', Integer, ForeignKey('ids_lctr.id'), primary_key=True)
)

class Document(Node):
    """
    After INode and Resource, the most abstract representation of a (file-based) 
    resource in taxus.
    A document comprises a set of elements in an unspecified further structure.

    Systems may allow muxing or demuxing a document from or resp. to its
    elements, Ie. the document object is interchangable by the set of its
    elements (although Node attributes may not be accounted for).

    sameAs
        Incorporates sameAs from N3 to indicate references that may have
        different access protocols but result in the same object
        (properties/actions)?
    """
    __tablename__ = 'docs'
    __mapper_args__ = {'polymorphic_identity': 'doc'}
    doc_id = Column('id', Integer, ForeignKey('nodes.id'))
#    elements = relationship('Element', secondary=doc_root_element_table)


#class ReCoDoc(Document):
#    """
#    ree-CO-doc, Recursive Container document describes the way hierarchical
#    container based formats provide a serial view of systems and domain objects.
#
#    Some may be canonical, or ambigious, generic or very specific, etc.
#    It forces serialization and a way to look at the resource as a single
#    stream with discrete, nested elements (iow. XML with either some DOMesque
#    interface or serial access interface). 
#
#    TODO: It implements sameAs to indicate ...
#    """
#    __tablename__ = 'rcdocs'
#    __mapper_args__ = {'polymorphic_identity': 'rcdoc'}
#    rcdoc_id = Column('id', Integer, ForeignKey('docs.id'))
#    host = relationship('Host', primaryjoin="Locator.host_id==Host.host_id",
#        backref='locations')
#
#
#class Element(Node):
#    """
#    Part of a Document.
#
#    XXX: I've allowed for re-use by placing a list of element instances on the
#    Document, instead of coding each element with an origin.
#
#    XXX: Subtypes may specificy how Node attributes map to the element objects
#    and/or additional attributes to consitute an element. E.g. an XML Subtype
#    specifies a list with textnodes and/or elements, besides a tag and attributes.
#    XML only has one rootelement per document.
#    """
#    __tablename__ = 'docelems'
#    __mapper_args__ = {'polymorphic_identity': 'docelem'}
#    docelem_id = Column('id', Integer, ForeignKey('nodes.id'))
#    # not much to say yet. there is a numeric ID, (possibly unique) name,
#    # dates and (possible) subtype. Not much else to say.


#class Schema(Variant):
#    """
#    TODO This would define schema information for or one more namespaces.
#    """
#    __tablename__ = 'schema'
#    __mapper_args__ = {'polymorphic_identity': 'resource:variant:schema'}
#
#    namespaces = []




