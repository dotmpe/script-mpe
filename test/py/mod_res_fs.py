import os
import unittest

from zope.interface.verify import verifyObject

from script_mpe import res
from script_mpe.res import iface
from script_mpe.res import fs


class TestResFs(unittest.TestCase):

    def setUp(self):
        self.pwd = os.getcwd()

    def test_fs_iface(self):
        root = fs.INode.factory('/')
        return # FIXME: test_fs_iface
        assert iface.Node.providedBy(root), root
        verifyObject( iface.Node, root)

        tree = iface.ITree( root )
        assert iface.ITree.providedBy(tree), tree
        verifyObject( iface.ITree, tree )

    def tearDown(self):
        assert self.pwd == os.getcwd(), (self.pwd, os.getcwd())


def get_cases():
    return [
            TestResFs
        ]

if __name__ == '__main__':
    unittest.main()
