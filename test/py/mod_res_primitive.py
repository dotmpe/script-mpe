import os
import unittest

from zope.interface.verify import verifyObject
from zope.component import getGlobalSiteManager

from script_mpe.res import primitive, fs, iface




class TreeNodeDictTest(unittest.TestCase):

    def setUp(self):
        self.pwd = os.getcwd()

    def test_ifaces(self):
        tree = primitive.TreeNodeDict(u'name')
        verifyObject( iface.Node, tree )
        verifyObject( iface.ITree, tree )

    def test_name(self):
        tree = primitive.TreeNodeDict(u'<root>')
        assert tree.__name__ == u'<root>'

    def test_nodeid(self):
        tree = primitive.TreeNodeDict(u'<root>')
        assert tree.nodeid == u'<root>'

    def test_tree_append(self):
        tree = primitive.TreeNodeDict(u'<root>')
        assert tree.nodeid == u'<root>'
        return # FIXME: TreeNodeDict
        for x in tree.subnodes:
          print x
        assert len(tree.subnodes) == 0, len(tree.subnodes)
        subnode = primitive.TreeNodeDict(u'<node>')
        tree.append(subnode)
        self.assert_( tree.subnodes == [ subnode ], tree.subnodes )

    def test_conform(self):
        tree = primitive.TreeNodeDict(  )

    def test_tree_traverse(self):
        #return # FIXME recursing in test_tree_traverse
        tree = primitive.TreeNodeDict(u'<root>')
        subnode = primitive.TreeNodeDict(u'<node>')
        tree.append(subnode)
        #visitor = AbstractHierarchicalVisitor()
        visitor = primitive.NodeIDExtractor()
        r = visitor.traverse(tree)
        # FIXME self.assert_( list(r) == [ tree, subnode ] )

    def tearDown(self):
        assert self.pwd == os.getcwd(), (self.pwd, os.getcwd())


def test_dictnode_fs_populate(): # TEST creating a dicttree from fs
    root = 'res'
    gsm = getGlobalSiteManager()
    localfs_service = gsm.queryUtility(iface.ILocalNodeService, 'fs')
    return # FIXME test_dictnode_fs_populate
    rootnode = localfs_service(root)
    tree = primitive.TreeNodeDict(None)
# XXX ITraveler + Updater
    visitor = primitive.NodeUpdater(tree)
    traveler = iface.ITraveler(tree)
    tree.travel(rootnode, visitor)
    #list ( visitor.traverse( rootnode ) )

def test_tree():
    from script_mpe import confparse
    root = 'res'
    opts = confparse.Values({})
    tree_init = {}
    # FIXME fs.Dir.tree( root, opts, tree_init )

def test_treenodedict():
    # nodes will be root of a node structure
    nodes = primitive.TreeNodeDict()
    # get the right iface for IHierarchicalVisitor
    # FIXME tree = iface.ITree( nodes )


def get_cases():
    return [
            TreeNodeDictTest,
            unittest.FunctionTestCase( test_dictnode_fs_populate ),
            unittest.FunctionTestCase( test_tree ),
            unittest.FunctionTestCase( test_treenodedict )
        ]


if __name__ == '__main__':
    #test_tree_traverse()
    #test_dictnode_fs_populate()
    unittest.main()
