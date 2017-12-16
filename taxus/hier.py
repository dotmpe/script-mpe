"""
"""
from sqlalchemy import Column, Integer, String, Boolean, Text, \
    ForeignKey, Table, Index, DateTime, select, func
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import relationship, backref, remote, foreign
from sqlalchemy.orm.collections import attribute_mapped_collection
from sqlalchemy.sql.expression import cast

from .init import SqlBase
from .util import ORMMixin
from .mixin import CardMixin



class Outline(SqlBase, CardMixin, ORMMixin):

    """
    """

    __tablename__ = 'outlines'
    id = Column(Integer, primary_key=True)
    parent_id = Column(Integer, ForeignKey(id))
    # Outline Node type
    ntype = Column(String(36), nullable=False, default="node")
    __mapper_args__ = {'polymorphic_on': ntype,
            'polymorphic_identity': 'node'}

    children = relationship(
        "Outline",
        # cascade deletions
        cascade="all, delete-orphan",
        single_parent=True,

        backref=backref("parent", remote_side=id),
    )

    def __init__(self, **kwds):
        for k in kwds:
            if kwds[k]:
                setattr(self, k, kwds[k])

    def __repr__(self):
        return "Outline(id=%r, parent_id=%r)" % (
            self.id,
            self.parent_id
        )

    @classmethod
    def proc_context(klass, item):
        if item.record_id:
            topic = OulineFolder.get_instance(name=item.record_id)
            if not topic:
                topic = OutlineFolder(name=item.record_id, header=item.text)
                topic.add_self_to_session()
        elif item.cites:
            if len(item.cites) != 1:
                print 'too manu cites:', repr(item), item.cites
                return
            group = OutlineFolder.get_instance(name=item.cites[0])
            if item.hrefs:
                assert len(item.hrefs) == 1, repr(item)
                sa = klass.get_session()
                bm = sa.query(OutlineBookmark).filter(OutlineBookmark.href==item.hrefs[0]).all()
                if bm:
                    print "Dupe", bm, item.hrefs
                    return
                bm = OutlineBookmark(description=item.text, parent=group, href=item.hrefs[0])
                bm.add_self_to_session()
            else:
                print("Unexpected %r, %r" % ( item, item.record_id ))

        #print 'TODO: Outline.proc_context', item


class OutlineFolder(Outline):

    __tablename__ = 'outline_folders'
    __mapper_args__ = {'polymorphic_identity': 'folder'}
    folder_id = Column('id', Integer, ForeignKey('outlines.id'), primary_key=True)
    name = Column(String(50), unique=True, nullable=False)

    #children = relationship(
    #    "Outline",
    #    # cascade deletions
    #    cascade="all, delete-orphan",
    #    single_parent=True,

    #    # many to one + adjacency list - remote_side
    #    # is required to reference the 'remote'
    #    # column in the join condition.
    #    backref=backref("parent", remote_side=folder_id),

    #    # children will be represented as a dictionary
    #    # on the "name" attribute.
    #    #collection_class=attribute_mapped_collection('name'),
    #)

    def __init__(self, name, **kwds):
        super(OutlineFolder, self).__init__(**kwds)
        self.name = name

    def dump(self, _indent=0):
        return "   " * _indent + repr(self) + \
            "\n" + \
            "".join([
                c.dump(_indent + 1)
                for c in self.children.values()
            ])


class OutlineBookmark(Outline):

    __tablename__ = 'outline_bookmarks'
    __mapper_args__ = {'polymorphic_identity': 'bookmark'}
    bookmark_id = Column('id', Integer, ForeignKey('outlines.id'), primary_key=True)
    description = Column(String(50), nullable=False)
    href = Column(String(255), nullable=True)

    def __init__(self, description, **kwds):
        super(OutlineBookmark, self).__init__(**kwds)
        self.description = description



class MaterializedPath(SqlBase, ORMMixin):
    """
    An ID/path record designed to order according to hierarchical rules.
    The MaterializedPath model encodes hierarchy in the second field, requiring
    a rewrite of all paths "below" a mutation. But allowing for fast, indexed
    key/ID lookup.

    From the SQLAlchemy documentation [#]_, Adjacency List Relationships are
    self-referential records and "he most common way to represent hierarchical
    data in flat tables" [#]_. The MaterializedPath is one of three methods
    presented in the documentation.

    .. [#] http://docs.sqlalchemy.org/en/latest/contents.html
    .. [#] http://docs.sqlalchemy.org/en/latest/orm/self_referential.html
    .. [#] http://docs.sqlalchemy.org/en/latest/_modules/examples/materialized_paths/materialized_paths.html

    NOTE: postgres only
    """
    __tablename__ = "paths"

    id = Column(Integer, primary_key=True, autoincrement=False)
    path = Column(String(500), nullable=False, index=True)

    # To find the descendants of this node, we look for nodes whose path
    # starts with this node's path.
    descendants = relationship(
        "MaterializedPath", viewonly=True, order_by=path,
        primaryjoin=remote(foreign(path)).like(path.concat(".%")))

    # Finding the ancestors is a little bit trickier. We need to create a fake
    # secondary table since this behaves like a many-to-many join.
    secondary = select([
        id.label("id"),
        func.unnest(cast(func.string_to_array(
            func.regexp_replace(path, r"\.?\d+$", ""), "."),
            ARRAY(Integer))).label("ancestor_id")
    ]).alias()
    ancestors = relationship("MaterializedPath", viewonly=True, secondary=secondary,
                             primaryjoin=id == secondary.c.id,
                             secondaryjoin=secondary.c.ancestor_id == id,
                             order_by=path)

    @property
    def depth(self):
        return len(self.path.split(".")) - 1

    def __repr__(self):
        return "MaterializedPath(id={})".format(self.id)

    def __str__(self):
        root_depth = self.depth
        s = [str(self.id)]
        s.extend(((n.depth - root_depth) * "  " + str(n.id))
                 for n in self.descendants)
        return "\n".join(s)

    def move_to(self, new_parent):
        new_path = new_parent.path + "." + str(self.id)
        for n in self.descendants:
            n.path = new_path + n.path[len(self.path):]
        self.path = new_path


#class NestedSets(SqlBase, ORMMixin):
#
#    """
#    Ie. ModifiedPreorder
#    """

models = []
