import unittest


import confparse2
from confparse2 import obj_dic, obj_lis



class CP2Test1(unittest.TestCase):

    def test_1_read_dict(self):
        d = obj_dic({'test':'foo'})
        self.assertEquals(str(d.test), 'foo')
        self.assertEquals(d.test, str(d.test))

    def test_1_read_dict_int(self):
        d = obj_dic({'test':1})
        self.assertEquals(d.test, 1)
        self.assertEquals(str(d.test), '1')

    def test_1_read_list(self):
        d = obj_lis(['foo'])
        self.assertEquals(str(d._0), 'foo')
        self.assertEquals(repr(d._0), repr(d._0))
        self.assertEquals(d[0], d._0)
        self.assertEquals(str(d[0]), str(d._0))

    def test_2_read_nested(self):
        d = obj_dic({'test':{'foo':'bar'}})
        self.assertEquals(d.test.foo, "bar")
        self.assertEquals(str(d.test.foo), "bar")
        self.assertEquals(repr(d.test.foo), "'bar'")
        #self.assertEquals(repr(d.test), "Conf({'test':{'foo':'bar'}})")

        d = obj_lis(['foo'])
        self.assertEquals(str(d._0), 'foo')
        self.assertEquals(d[0], d._0)
        #self.assertEquals(d[0].value, d._0.value)

    def test_write(self):

        d = obj_dic({})
        d.test = 'foo'
        self.assertEquals(d.copy(), {'test':'foo'})
        self.assertEquals(type(d), d.__class__)

        d.test2 = {'foo': 'bar'}
        self.assertEquals(d.copy(), {'test':'foo','test2':{'foo':'bar'}})
        #self.assertEquals(type(d.test2), d.__class__)
        #self.assertEquals(type(d.test2), confparse2.PropertyValue)        
        #self.assertEquals(type(d.test2.foo), confparse2.PropertyValue)        


def get_cases():
    return [
            CP2Test1, 
        ]


if __name__ == '__main__':
    unittest.main()

