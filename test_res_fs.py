import unittest

from zope.interface.verify import verifyObject

import res.iface
import res.fs


class TestResFs(unittest.TestCase):

    def test_fs_iface(self):
        root = res.fs.INode.factory('/')
        assert res.iface.Node.providedBy(root), root
        verifyObject( res.iface.Node, root)

        tree = res.iface.ITree( root )
        assert res.iface.ITree.providedBy(tree), tree
        verifyObject( res.iface.ITree, tree )

if __name__ == '__main__':
    unittest.main()
