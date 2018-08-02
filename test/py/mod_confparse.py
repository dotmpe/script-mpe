#!/usr/bin/env python
import sys
import os
from os import unlink, removedirs, makedirs, chdir, \
        getcwd, popen, rmdir
from os.path import join, dirname, exists, isdir, realpath
import unittest
from pprint import pformat
import tempfile

from script_mpe import confparse
from script_mpe.confparse import expand_config_path, load



class AbstractConfparseTest(unittest.TestCase, object):

    RC_DATA = """\nfoo: \n   bar: {var: v}\n   test4: [{foo: bar}]"""

    def setUp(self):
        # FIXME: path affects test, update params
        #self.tmpf = tempfile.mkstemp()
        #self.tmpdir = tempfile.mkdtemp()
        if sys.platform.lower() == 'darwin':
            self.tmpdir = '/private/var/tmp/'
        elif sys.platform.lower() == 'linux2':
            self.tmpdir = '/tmp/'
        else:
            raise Exception ("Uknown platform: %s" % sys.platform)
        self.testrootdir = join(self.tmpdir, self.NAME)
        makedirs(self.testrootdir)

        self.pwd = join(self.testrootdir, self.PWD)
        makedirs(self.pwd)

        self.cwd = getcwd()
        chdir(self.pwd)
        open(self.RC, 'w+').write(self.RC_DATA)
        #self._print_test_files()

    def tearDown(self):
        #self._print_test_files()
        chdir(self.pwd)
        unlink(self.RC)
        chdir(self.cwd)
        removedirs(self.pwd)

    def _print_test_files(self):
        #print os.popen('tree -a %s' % self.testrootdir).read()
        cwd = getcwd()
        #print popen('tree -a %s' % cwd).read()



class CPTest2(AbstractConfparseTest):

    NAME = 'test2'
    RC = 'testrc'
    PWD = 'test/sub/dir/'

    def confparse_test_func1_(self):
        self._print_test_files()
        conf = expand_config_path(self.NAME).next()
        #self.assertEqual(conf, self.name)
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

    def setUp(self):
        self.name = 'cllct/project'
        self.cwd = getcwd()
        chdir('/tmp')
        makedirs('.cllct/')
        self.realname = realpath('.'+self.name)
        open(self.realname, 'w+').write("id: 1\n")

    def test_1(self):
        self.assert_(exists(self.realname))
        rcfile = list(confparse.expand_config_path(self.name))
        self.assertEqual(rcfile, [self.realname])

    def test_2(self):
        settings = load(self.name)
        self.assert_('id' in settings)

    def tearDown(self):
        unlink('.cllct/project')
        rmdir('.cllct/')
        chdir(self.cwd)


class CPTest1(AbstractConfparseTest):

    """
    Work on settings in test/.testrc from test/sub/dir/
    """

    NAME = 'test1'
    RC = 'testrc'
    PWD = 'test/sub/dir/'

    def test_0_init(self):
        self.assert_(exists(self.testrootdir))
        self.assert_(isdir(self.testrootdir))
        self.assert_(exists(self.pwd))
        self.assert_(isdir(self.pwd))
        self.assertEqual(getcwd(), realpath(self.pwd))
        self.assert_(exists(self.RC))
        #self._print_test_files()

    def confparse_test_func1_find_config(self):
        rcs = list(expand_config_path('testrc'))
        self.assertEqual(rcs, [join(getcwd(), self.RC)])
        test_runcom = expand_config_path('testrc').next()
        return test_runcom

    def test_1_exports(self):
        expected_exports = [
                'name_prefixes',
                'path_prefixes',
                'name_suffixes',
                'tree_paths',
                'expand_config_path',
                'find_config_path',
                'DictDeepUpdate',
                'Values',
                'backup',
                'YAMLValues',
                'FSValues',
                'yaml',
                'init_config',
                'load_path',
                'load',
            ]
        for export in expected_exports:
            self.assert_(lambda x: getattr(confparse, export))

    def test_2_load(self):
        test_settings = load(self.RC)
        self.assertEqual(getattr(confparse._, self.RC), test_settings)

        self.assert_('foo' in test_settings)
        self.assert_('bar' in test_settings.foo)
        self.assert_('var' in test_settings.foo.bar)
        self.assert_(test_settings.source_key in test_settings)

        self.assertEqual(test_settings.default_source_key, 'config_file')
        source_key = test_settings.source_key
        self.assertEqual(source_key, 'config_file')
        self.assert_(hasattr(test_settings, source_key))

        self.assertEqual(test_settings.default_config_key, 'default')
#        self.assertEqual(test_settings.config_key, 'config_file')

        self.assertEqual(self.tmpdir+'test1/'+self.PWD+'testrc', getattr(test_settings, source_key))
        # XXX: merge configs? self.assertEqual(tmpdir+'test1/.testrc', getattr(test_settings, source_key))

        test_settings.foo.bar.mod = load(self.RC)
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
        pwd = getcwd()
        test_settings = load(self.RC, paths=confparse.path_prefixes+(pwd,))
        self.assertEqual(test_settings.copy(True), {
            'foo': {
                'bar': {'var': 'v'},
                'test4': [{'foo': 'bar'}],
            },
            #'file': '/tmp/test1/.testrc',
            'config_file': self.tmpdir + 'test1/test/sub/dir/testrc',
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
            #'file': '/tmp/test1/.testrc'
            'config_file': self.tmpdir + 'test1/test/sub/dir/testrc',
        });
        #print test_settings
        #print test_settings.keys()
        return test_settings

    def test_6_commit(self):
        test_settings = self.test_5_copy()

        self.assertEqual(test_settings.getsource(), test_settings)
        # FIXME: should get commit working with multiple modules, see
        # dev_confparse_hier
        #test_settings.commit()

        # FIXME: confparse.commit is not really tested
        #test_settings.reload()
        test_settings = self.test_5_copy()
        self.assertEqual(test_settings.copy(), {
            'test1': 'value',
            'test2': {
                'foo': {'bar': {'z': 'value3'}}},
            'foo': {
                'bar': {'var': 'v'},
                'test4': [{'foo': 'bar'}],
            },
            #'config_file': self.tmpdir+'test1/.testrc'
            'config_file': self.tmpdir + 'test1/test/sub/dir/testrc'
        });



def confparse_test_func1():
    from confparse import yaml
    from pprint import pformat

    #cllct_settings = ini(cllct_runcom) # old ConfigParser based, see confparse experiments.
    test_settings = yaml(test_runcom)

    #print 'test_settings', pformat(test_settings)

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


def test_new():
    """

        testroot/.cllct/myConfig.ext
        testroot/sub/.cllct/myConfig.ext
        testroot/sub/sub2/.myConfig.ext
        testroot/sub/sub2/.myConfigLocal.ext

        root: Values
            parent_key: root
            source_key: myConfig(1)

            myValue: 1

            sub: Values
                parent_key: sub
                source_key: myConfig(2)

                mySubValue: 1

            sub: Values
                overlay: sub
                source_key: myConfig(3)

                mySubValue: 2

        root: Values
            parent_key: root
            source_key: myConfigLocal

            myValue: 2

        source:
            myConfig(1): testroot/.cllct/myConfig.ext
            myConfig(2): testroot/sub/.cllct/myConfig.ext
            myConfig(3): testroot/sub/sub2/.myConfig.ext
            myConfigLocal: testroot/sub/sub2/.myConfigLocal.ext

    This enables the two main scenario, I want to override any value in the tree,
    or I wish to amend the configuration with a sub-section. Which can also be
    overriden, from other directories.

    The current directory determines the view of the configuration tree.
    There is two trees. One from the directories, and one of the key-values
    (keys can have subsections as value).

    Only a few source keys would be loaded at once for a specific app,
    Multiple may exist without being loaded all at once.
    Source-keys are numbered automatically.

    Each file lists its parent-key. The source-key is automatic after the filename.

    Each key, value has its canonical file, which is the last file to appear in
    the tree, ordered by its source-key (filename length.. and alphanum? but no
    exception should happen?).

    Iow. when updated, the change will be committed to this file.
    The value may behave as a stack, where we can delete an override.
    """


class Values2Test(unittest.TestCase):
	def makeFiles(self, *resources):
		testroot = '/tmp/values2'
		for name, contents in resources:
			path = os.path.join( testroot, name )
			dirs = os.path.dirname(path)
			if not os.path.exists(dirs):
				os.makedirs(dirs)
			open( path, 'w+' ).write(contents)
		return testroot
	def setUp(self):
		self.testDir = self.makeFiles(
				('.cllct/myConfig.yaml', "parent_key: default\nmyValue: 1"),
				('sub/.cllct/myConfig.yaml', "parent_key: sub\nmySubValue: 1"),
				('sub/sub2/.myConfig.yaml', "parent_key: sub\nmySubValue: 2"),
				('sub/sub2/.myConfigLocal.yaml', "parent_key: default\nmyValue: 2"),
			)
		self.pwd = os.getcwd()
	def tearDown(self):
		assert self.pwd == os.getcwd(), (self.pwd, os.getcwd())
	#def test_(self):
	#	from subprocess import Popen
	#	p = Popen("tree" + " -aifgup %s" % self.testDir, shell=True)
	#	pid, sts = os.waitpid(p.pid, 0)

	def test_1(self):
	        pwd = os.getcwd()
		chdir(join(self.testDir, 'sub/sub2'))
		config = confparse.load_all(
		        ['myConfig', 'myConfigLocal'], alt_paths=['~/', './'],
			prefixes=['', '.', '.cllct/'], exts=['.yaml'])
		print(config.todict())
		self.assertEqual( config.myValue, 2 )
		self.assertEqual( config.sub.mySubValue, 2 )
		self.assertEqual( config.source.myConfig_1, 'testroot/.cllct/myConfig.ext' )
		chdir(pwd)


# TODO: test values
def get_cases():
	return [
			CPTest2,
			CPTest1,
			#            unittest.FunctionTestCase( confparse_test_func1 )
		]


if __name__ == '__main__':
	unittest.main()
