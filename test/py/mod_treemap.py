"""
"""
import unittest

from script_mpe import treemap, res


class TreemapUnitTest(unittest.TestCase):

    def test_1_fs_tree(self):
        path = './'
        tree = treemap.fs_tree(unicode(path))
        for node in tree.subnodes:
            assert isinstance(node, res.primitive.TreeNodeDict), (type(node), node)
            #assert isinstance(node, treemap.Node), (type(node), node)

    def test_2_fs_sizes_tree(self):
        path = './'
        tree = treemap.fs_tree(unicode(path))

        #treemap.fs_treesize(path, tree)
        #print tree.value
        #print tree.size
        #print tree.getattrs()

        #for node in tree.subnodes:
        #    assert isinstance(node, treemap.Node)
        #    assert node.size



# Return module test cases

def get_cases():
    return [
            TreemapUnitTest
        ]

# Or start unittest

if __name__ == '__main__':
    unittest.main()

