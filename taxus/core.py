"""
Docs are in taxus/__init__
"""
from datetime import datetime

import zope.interface
from sqlalchemy import Column, Integer, String, Boolean, Text, \
    ForeignKey, Table, Index, DateTime, select, func, or_
#from sqlalchemy.orm.exc import NoResultFound
from sqlalchemy.orm import relationship, backref, remote, foreign
from sqlalchemy.orm.collections import attribute_mapped_collection


from . import iface
from .mixin import CardMixin
from .init import SqlBase
from .util import ORMMixin

from script_mpe import lib, log


class Node(SqlBase, CardMixin, ORMMixin):

    """
    Provide lookup on numeric ID, and standard dates.
    """

    zope.interface.implements(iface.Node)

    __tablename__ = 'nodes'

    # Node type
    ntype = Column(String(36), nullable=False, default="node")
    __mapper_args__ = {'polymorphic_on': ntype,
            'polymorphic_identity': 'node'}

    # Numeric ID
    node_id = Column('id', Integer, primary_key=True)

    # Context ID
    space_id = Column(Integer, ForeignKey('spaces.id'))
    space = relationship(
            'Space',
            #primaryjoin='Node.space_id == Space.space_id'
            backref='objects',
#            remote_side='spaces.id',
#            foreign_keys=[space_id]
        )

    @classmethod
    def default_filters(klass):
        return (
            ( klass.deleted == False ),
        )

    def __repr__(self):
        return "<%s at %s for %r>" % (lib.cn(self), hex(id(self)), self.node_id)

    def __str__(self):
        return "%s for %r" % (lib.cn(self), self.node_id)


groupnode_node_table = Table('groupnode_node', SqlBase.metadata,
    Column('node_id', Integer, ForeignKey('nodes.id'), primary_key=True),
    Column('groupnode_id', Integer, ForeignKey('groupnodes.id'), primary_key=True)
)

class GroupNode(Node):

    """
    A bit of a stop-gap mechanisms by lack of better containers
    in the short run.
    Like the group nodes in outlines and bookmark files.
    """

    __tablename__ = 'groupnodes'
    __mapper_args__ = {'polymorphic_identity': 'group'}
    group_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)

    subnodes = relationship(Node, secondary=groupnode_node_table, backref='supernode')
    root = Column(Boolean)


class Folder(GroupNode):

    """
    A group-node with a shared title?
    """

    __tablename__ = 'folders'

    __mapper_args__ = {'polymorphic_identity': 'folder'}
    folder_id = Column('id', Integer, ForeignKey('groupnodes.id'), primary_key=True)

    title_id = Column(Integer, ForeignKey('names.id'))
    title = relationship('Name', primaryjoin='Folder.title_id==Name.name_id')



class ID(SqlBase, CardMixin, ORMMixin):

    """
    A global system identifier stored in varchar(255)
    """

    zope.interface.implements(iface.IID)

    __tablename__ = 'ids'
    id_id = Column('id', Integer, primary_key=True)

    idtype = Column(String(50), nullable=False)
    __mapper_args__ = {'polymorphic_on': idtype, 'polymorphic_identity': 'id' }

    global_id = Column(String(255), index=True, unique=True, nullable=False)

    def __repr__(self):
        return "<%s at %s for %r>" % (lib.cn(self), hex(id(self)), self.global_id)


class Space(ID):

    """
    Spaces segment the Nodeverse.

    An abstraction to deal with segmented storage (ie. different databases,
    hosts).

    NOTE: just storing some specs in this base for now
    """

    __tablename__ = 'spaces'

    __mapper_args__ = {'polymorphic_identity': 'space'}

    space_id = Column('id', Integer, ForeignKey('ids.id'), primary_key=True)

    #backend_id = ...
    classes = Column(String(255))


class Scheme(Space):

    """
    Reserved names for Locator schemes.
    """

    __tablename__ = 'schemes'
    __mapper_args__ = {'polymorphic_identity': 'scheme-space'}
    scheme_id = Column('id', Integer, ForeignKey('spaces.id'), primary_key=True)


class Protocol(Scheme):

    """
    Reserved names for Locator schemes.
    """

    __tablename__ = 'protocols'
    __mapper_args__ = {'polymorphic_identity': 'protocol-scheme-space'}
    protocol_id = Column('id', Integer, ForeignKey('schemes.id'), primary_key=True)


class Name(Node):

    """
    A local unique unicode string without character restrictions; a title or
    name or other user-provided identifier.
    """

    __tablename__ = 'names'
    __mapper_args__ = {'polymorphic_identity': 'name'}
    name_id = Column('id', Integer, ForeignKey('nodes.id'), primary_key=True)

    # Unique string without character restrictions (aka User-ID-Label)
    name = Column(String(255), nullable=False, index=True, unique=True)


class Tag(Name):

    """
    A unique ASCII identifier for Names.

    XXX: name unique within some namespace?

    Because tags are unqiue, there is no need for complex keys like in
    materialized paths pattern. But it requires a complex query to get the path.

    Importing a tag from an existing namespace should get it supernodes as well.
    """

    #zope.interface.implements(iface.IID)

    __tablename__ = 'tagnames'
    __mapper_args__ = {'polymorphic_identity': 'tag'}

    tag_id = Column('id', Integer, ForeignKey('names.id'), primary_key=True)

    # Unqiue, normalized restricted char ASCII string
    tag = Column(String(255), unique=True, nullable=False)

    # One line defition, title, short description
    short_description = Column(Text, nullable=True)

    # Full user description
    description = Column(Text, nullable=True)

    def __str__(self):
        if self.short_description:
            return "%s <%s>: %s" % ( self.name, self.tag, self.short_description )
        else:
            return "%s <%s>" % ( self.name, self.tag)

    @classmethod
    def clean_tag(klass, raw):
        yield raw.strip(' \n\r')

    @classmethod
    def record(klass, raw, sa, g):
        """
        Create and return. Existing record is error in strict-mode,
        FIXME: cleanup
        """
        def record_inner(name):
            tag = None
            try:
                tag = sa.query(Tag).filter(Tag.name == name).one()
                print('exists')
            except: pass
            if tag:
                if not g.strict:
                    return tag
                raise Exception("Exact tag match exists '%s'" % tag)

            tag_matches = sa.query(Tag).filter(or_(
                Tag.name.like('%'+stem+'%') for stem in
                    klass.clean_tag(name) )).all()

            if tag_matches:# and not g.override_prefix:
                # TODO
                g.interactive
                print('Existing match for %s:' % name)
                for t in tag_matches:
                    print(t)
                raise ValueError
            else:#if not tag_matches:# or g.override_prefix:
                tag = Tag(name=name, tag=name)
                tag.add_self_to_session(name=g.session_name)
                return tag

        if '/' in raw:
            els = raw.split('/')
            while els:
                tag = None
                print(record_inner(els[0]))
                els.pop(0)
        else:
            print(record_inner(raw))
        sa.commit()

    # TODO: later migrate tag to topic or other specific scheme, with ns/spec..
    #namespace_id = Column(Integer, ForeignKey('ns.id'))
    #tag = relationship('Localname', backref='tags')


# Populate Tag.context with optionally recorded tag-usage realtions

tag_context_table = Table('tag_context', SqlBase.metadata,
        Column('tag_id', Integer, ForeignKey('tagnames.id'), primary_key=True),
        Column('ctx_id', Integer, ForeignKey('tagnames.id'), primary_key=True),
        Column('role', String(32), nullable=True)
)

Tag.contexts = relationship('Tag', secondary=tag_context_table,
            primaryjoin=( Tag.tag_id == tag_context_table.columns.tag_id ),
            secondaryjoin=( Tag.tag_id == tag_context_table.columns.ctx_id ),
            backref='contains')


# Record accumulated usage statistics for tag, populate Tag.freq
tags_freq = Table('names_tags_stat', SqlBase.metadata,
        Column('tag_id', ForeignKey('tagnames.id'), primary_key=True),
        Column('frequency', Integer)
)
#Tag.freq =


class Topic(Tag):

    """
    A Name/Tag node with XXX: ex/implicit about relations to path or resource.
    """

    __tablename__ = 'tagnames_topic'
    __mapper_args__ = {'polymorphic_identity': 'topic'}
    topic_id = Column('id', Integer, ForeignKey('tagnames.id'), primary_key=True)

    super_id = Column(Integer, ForeignKey('tagnames_topic.id'))
    subs = relationship("Topic",
        cascade="all, delete-orphan",
        backref=backref('super', remote_side=[topic_id]),
        foreign_keys=[super_id],
        collection_class=attribute_mapped_collection('name'),
    )

    # some plain metadata
    explanation = Column(Text(65535))
    location = Column(Boolean)
    thing = Column(Boolean)
    event = Column(Boolean)
    plural = Column(String(255))

    def __init__(self, name, super=None):
        self.name = name
        self.super = super
        self.init_defaults()

    def __repr__(self):
        return "Topic(name=%r, id=%r, super_id=%r)" % (
            self.name,
            self.topic_id,
            self.super_id
        )

    def path(self, sep='/'):
        e = [self.name]
        c = self
        while c.super:
            c = c.super
            e.append(c.name)
        e.reverse()
        return sep.join(e)

    def paths(self, sep='/', _indent=0):
        return "\t"*_indent + self.name + sep +"\n"+ "".join([
                c.paths(_indent=_indent + 1)
                for c in self.subs.values()
            ])

    def dump(self, _indent=0):
        return "   " * _indent + repr(self) + \
            "\n" + \
            "".join([
                c.dump(_indent + 1)
                for c in self.subs.values()
            ])

    @classmethod
    def proc_context(klass, item):
        print 'TODO: Topic.proc_context', item


doc_root_element_table = Table('doc_root_element', SqlBase.metadata,
    Column('inode_id', Integer, ForeignKey('inodes.id'), primary_key=True),
    Column('lctr_id', Integer, ForeignKey('ids_lctr.id'), primary_key=True)
)

class Document(Space):

    """
    Document is an (invariant?) instance for a resource with a unique title,
    and one specific location. Probably with a htdocs:volume: scheme

    XXX: see htd.TNode.
    """
    __tablename__ = 'docs'
    __mapper_args__ = {'polymorphic_identity': 'space-doc'}

    doc_id = Column('id', Integer, ForeignKey('spaces.id'), primary_key=True)

    title_id = Column('title_id', Integer, ForeignKey('names.id'))
    title = relationship(Name, primaryjoin='Document.title_id==Name.name_id')

    #elements = relationship('Element', secondary=doc_root_element_table)


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



models = [

        Node, Space,

        GroupNode,

        Document,
        ID,
        Name, Tag, Topic

    ]
