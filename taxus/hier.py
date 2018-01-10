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



def cmd_x_tree(g):
    """
    Adjacency list model
    """
    session = Topic.get_session('default', g.dbref)
    def msg(msg, *args):
        msg = msg % args
        print("\n\n\n" + "-" * len(msg.split("\n")[0]))
        print(msg)
        print("-" * len(msg.split("\n")[0]))

    msg("Creating Tree Table:")

    root = Topic('root(1)')
    node1 = Topic('node(1)', root)
    node3 = Topic('node(3)', root)

    session.add(root)
    session.commit() # otherwise subnodes['node4' isnt there

    root2 = Topic('root(2)')
    Topic('subnode(1)', root2)
    root.subnodes['root-2'] = root2
    Topic('subnode(2)', root.subnodes['root-2'])

    msg("Created new tree structure:\n%s", root.dump())
    msg("flush + commit:")
    session.add(root)
    session.commit()

    msg("Tree After Save:\n %s", root.dump())
    Topic('root(4)', root)
    session.commit() # otherwise subnodes['root(4)' isnt there
    Topic('subnode(3)', root.subnodes['root-4'])
    Topic('subroot(4)', root.subnodes['root-4'])
    Topic('subnodesubnode(1)', root.subnodes['root-4'].subnodes['subnode-3'])

    # remove node-1 from the super, which will trigger a delete
    # via the delete-orphan cascade.
    del root.subnodes['node-1']

    msg("Removed node(1).  flush + commit:")
    session.commit()
    msg("Tree after save:\n %s", root.dump())

    msg("Emptying out the session entirely, selecting tree on root, using "
        "eager loading to join four levels deep.")
    session.expunge_all()
    node_ = session.query(Topic).\
        options(joinedload_all("subnodes", "subnodes",
                               "subnodes", "subnodes")).\
        filter(Topic.name == "rootnode").\
        first()

    msg("Paths:\n%s", root.paths())
    #msg("Full Tree:\n%s", root.dump())

    msg("Marking root root as deleted, flush + commit:")

    session.delete(root)
    session.commit()


def cmd_x_mp(g):
    """
    Example using materialized paths pattern.
    """
    session = MaterializedPath.get_session('default', g.dbref)

    print("-" * 80)
    print("create a tree")
    session.add_all([
        MaterializedPath(id=1, path="1"),
        MaterializedPath(id=2, path="1.2"),
        MaterializedPath(id=3, path="1.3"),
        MaterializedPath(id=4, path="1.3.4"),
        MaterializedPath(id=5, path="1.3.5"),
        MaterializedPath(id=6, path="1.3.6"),
        MaterializedPath(id=7, path="1.7"),
        MaterializedPath(id=8, path="1.7.8"),
        MaterializedPath(id=9, path="1.7.9"),
        MaterializedPath(id=10, path="1.7.9.10"),
        MaterializedPath(id=11, path="1.7.11"),
    ])
    session.flush()
    print(str(session.query(MaterializedPath).get(1)))

    print("-" * 80)
    print("move 7 under 3")
    session.query(MaterializedPath).get(7).move_to(session.query(MaterializedPath).get(3))
    session.flush()
    print(str(session.query(MaterializedPath).get(1)))

    print("-" * 80)
    print("move 3 under 2")
    session.query(MaterializedPath).get(3).move_to(session.query(MaterializedPath).get(2))
    session.flush()
    print(str(session.query(MaterializedPath).get(1)))

    print("-" * 80)
    print("find the ancestors of 10")
    print([n.id for n in session.query(MaterializedPath).get(10).ancestors])

    session.commit()
    session.close()


def cmd_x_al(g):
    session = MaterializedPath.get_session('default', g.dbref)

    def msg(msg, *args):
        msg = msg % args
        print("\n\n\n" + "-" * len(msg.split("\n")[0]))
        print(msg)
        print("-" * len(msg.split("\n")[0]))

    node = MaterializedPath('rootnode')
    MaterializedPath('node1', parent=node)
    MaterializedPath('node3', parent=node)

    node2 = MaterializedPath('node2')
    MaterializedPath('subnode1', parent=node2)
    node.children['node2'] = node2
    MaterializedPath('subnode2', parent=node.children['node2'])

    msg("Created new tree structure:\n%s", node.dump())

    msg("flush + commit:")

    session.add(node)
    session.commit()

    msg("Tree After Save:\n %s", node.dump())

    MaterializedPath('node4', parent=node)
    MaterializedPath('subnode3', parent=node.children['node4'])
    MaterializedPath('subnode4', parent=node.children['node4'])
    MaterializedPath('subsubnode1', parent=node.children['node4'].children['subnode3'])

    # remove node1 from the parent, which will trigger a delete
    # via the delete-orphan cascade.
    del node.children['node1']

    msg("Removed node1.  flush + commit:")
    session.commit()

    msg("Tree after save:\n %s", node.dump())

    msg("Emptying out the session entirely, selecting tree on root, using "
        "eager loading to join four levels deep.")
    session.expunge_all()
    node = session.query(MaterializedPath).\
        options(joinedload_all("children", "children",
                               "children", "children")).\
        filter(MaterializedPath.name == "rootnode").\
        first()

    msg("Full Tree:\n%s", node.dump())

    msg("Marking root node as deleted, flush + commit:")

    session.delete(node)
    session.commit()

