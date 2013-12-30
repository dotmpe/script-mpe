import unittest

import res.primitive


class TreeNodeDictTest(unittest.TestCase):

    def test_1_(self):
        d = res.primitive.TreeNodeDict('x')
        self.assertEquals(d.nodeid, 'x')
        assert 'x' in d
        self.assertEquals(d, {'x':None})
        self.assertEquals(d.attributes, {})
        self.assertEquals(d.subnodes, None)
        d.append(1)
        d.append(2)
        self.assertEquals(d.subnodes, [1,2])
        d.remove(1)
        self.assertEquals(d.subnodes, [2])
        self.assertEquals(d, {'x':[2]})
       
    def test_2_(self):
        d = res.primitive.TreeNodeDict('two')
        d.test = 'foo'
        self.assertEquals(d.prefix, '@')
        self.assertEquals(d, {'two':None, '@test':'foo'})
        self.assertEquals(d.attributes, {'test':'foo'})
        self.assertEquals(d.subnodes, None)


if __name__ == '__main__':
    unittest.main()
