from os import unlink, removedirs, makedirs, tmpnam, chdir, getcwd
from os.path import join, dirname, exists, isdir, realpath
import unittest
from pprint import pformat

import confparse
from confparse import expand_config_path, load



class TestCase(unittest.TestCase):

    def _print_test_files(self):
        import os
        print getcwd()
        print os.popen('tree -a %s' % self.testdir).read()


class AbstractConfparseTest(TestCase):

    def setUp(self):
        self.testdir = join(dirname(tmpnam()), self.NAME)
        makedirs(self.testdir)

        self.name = realpath(join(self.testdir, '.' + self.RC))
        makedirs(self.name)

        self.pwd = join(self.testdir, self.PWD)
        makedirs(self.pwd)

        self.cwd = getcwd()
        chdir(self.pwd)
        open(self.name, 'w+').write("""\nfoo: \n   bar: {var: v}\n   test4:
                [{foo: bar}]""")

        print self.testdir
        print self.name
        print self.pwd
        self._print_test_files()

    def tearDown(self):
        chdir(self.cwd)
        unlink(self.name)
        removedirs(self.pwd)
        #removedirs(self.testdir)

class Test2(AbstractConfparseTest):

    NAME = 'test2'
    RCS = ['testrc']
    PWD = 'test/sub/dir/'

    def test_1_(self):
        #self._print_test_files()
        conf = expand_config_path(self.NAME).next() 
        self.assertEqual(conf, self.name)
        settings = load(self.NAME)
        #self.assertEqual(load(conf), settings)
    """
    Values({
        'default':{},
        'global':{
            'config_file':'/etc/test2.rc'
        },
        'config_file':'/home/berend/.test2/rc',
        'net.example.my': {
            'foo':'bar',
        },
        'net.example.my2': {
            'config_file': '/tmp/my2/.rc',
            'foo': 'bar',
            'root': '/home/berend/.test2/rc',
            'sub': {
                'config_file': '/tmp/my2/sub/.rc',
                'foo2': 'bar',
                'root': '/tmp/my2/.rc',
            }
        }
    })
    """


class Test1(TestCase):

    """
    Work on settings in test/.testrc from test/sub/dir/
    """

    NAME = 'test1'
    RC = 'testrc'
    PWD = 'test/sub/dir/'

    def test_0_init(self):
        self.assert_(exists(self.testdir))
        self.assert_(isdir(self.testdir))
        self.assert_(exists(self.pwd))
        self.assert_(isdir(self.pwd))
        self.assertEqual(getcwd(), realpath(self.pwd))
        self.assert_(exists(self.name))
        #self._print_test_files()

    def test_1_find_config(self):
        rcs = list(expand_config_path('testrc'))
        test_runcom = '.testrc'
        self.assertEqual(rcs, [self.name])
        test_runcom = expand_config_path('testrc').next()
        return test_runcom

    def test_2_load(self):
        test_settings = load(self.RC)
        self.assertEqual(getattr(confparse._, self.RC), test_settings)
        self.assert_('foo' in test_settings)
        self.assert_('bar' in test_settings.foo)
        self.assert_('var' in test_settings.foo.bar)
        self.assert_(test_settings.source_key in test_settings)

        test_settings.foo.bar.mod = load(self.RC)
# XXX: darwin
        self.assertEqual(test_settings.default_config_key, 'config_file')
        self.assertEqual(test_settings.default_source_key, 'default')
        self.assertEqual(test_settings.config_key, 'config_file')
        self.assertEqual(test_settings.source_key, 'default')
        self.assert_('/private/var/tmp/test1/.testrc' == test_settings.file)
        self.assert_('foo' in test_settings.foo.bar.mod)
        self.assert_('bar' in test_settings.foo.bar.mod.foo)
        self.assert_('var' in test_settings.foo.bar.mod.foo.bar)

    def test_3_set_string(self):
        test_settings = load(self.RC)
        test_settings.test1 = 'value'
        self.assertEqual(test_settings.test1, 'value')
        test_settings['test2.foo.bar.z'] = 'value'
        self.assertEqual(test_settings.test2.foo.bar.z, 'value')
        test_settings.test2.foo.bar['z'] = 'value2'
        self.assertEqual(test_settings.test2.foo.bar.z, 'value2')
        test_settings.test2.foo.bar.z = 'value3'
        self.assertEqual(test_settings.test2.foo.bar.z, 'value3')

        self.assertEqual(test_settings.test2.foo.bar.path(), '.test2.foo.bar')
        #self.assertEqual(test_settings.test2.foo.bar.z.path(), '.test2.foo.bar.z')
        return test_settings

    def test_4_lists(self):
        test_settings = load(self.RC)
        test_settings.test3 = [1,2,3]
        self.assertEqual(test_settings.test3, [1,2,3])
        self.assertEqual(test_settings.foo.test4[0].foo, 'bar')

    def test_5_copy(self):
        test_settings = load(self.RC)
        self.assertEqual(test_settings.copy(), {
            'foo': {
                'bar': {'var': 'v'},
                'test4': [{'foo': 'bar'}], 
            }, 
            'file': '/private/var/tmp/test1/.testrc',
        });
        test_settings = self.test_3_set_string()
        self.assertEqual(test_settings.copy(), {
            'test1': 'value', 
            'test2': {
                'foo': {'bar': {'z': 'value3'}}},
            'foo': {
                'bar': {'var': 'v'},
                'test4': [{'foo': 'bar'}], 
            }, 
            'file': '/private/var/tmp/test1/.testrc'
        });
        #print test_settings
        #print test_settings.keys()
        return test_settings

    def test_6_commit(self):
        test_settings = self.test_5_copy()

        self.assertEqual(test_settings.getsource(), test_settings)
        test_settings.commit()

        test_settings.reload()
        self.assertEqual(test_settings.copy(), {
            'test1': 'value', 
            'test2': {
                'foo': {'bar': {'z': 'value3'}}},
            'foo': {
                'bar': {'var': 'v'},
                'test4': [{'foo': 'bar'}], 
            }, 
            'file': '/private/var/tmp/test1/.testrc'
        });


# Testing

def test1():
    #cllct_settings = ini(cllct_runcom) # old ConfigParser based, see confparse experiments.
    test_settings = yaml(test_runcom)

    print 'test_settings', pformat(test_settings)

    if 'foo' in test_settings and test_settings.foo == 'bar':
        test_settings.foo = 'baz'
    else:
        test_settings.foo = 'bar'

    test_settings.path = Values(root=test_settings)
    test_settings.path.to = Values(root=test_settings.path)
    test_settings.path.to.some = Values(root=test_settings.path.to)
    test_settings.path.to.some.leaf = 1
    test_settings.path.to.some.str = 'ABC'
    test_settings.path.to.some.tuple = (1,2,3,)
    test_settings.path.to.some.list = [1,2,3,]
    test_settings.commit()

    print 'test_settings', pformat(test_settings)

if __name__ == '__main__':
	unittest.main()

