import os
import unittest

from zope.interface.verify import verifyObject

import res.iface
import res.fs


class TestResFs(unittest.TestCase):

    def setUp(self):
        self.pwd = os.getcwd()

    def test_fs_iface(self):
        root = res.fs.INode.factory('/')
        return # FIXME: test_fs_iface
        assert res.iface.Node.providedBy(root), root
        verifyObject( res.iface.Node, root)

        tree = res.iface.ITree( root )
        assert res.iface.ITree.providedBy(tree), tree
        verifyObject( res.iface.ITree, tree )

    def tearDown(self):
        assert self.pwd == os.getcwd(), (self.pwd, os.getcwd())


def get_cases():
    return [
            TestResFs
        ]

if __name__ == '__main__':
    unittest.main()
