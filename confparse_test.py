from os import unlink, removedirs, makedirs, tmpnam, chdir, getcwd
from os.path import join, dirname, exists, isdir, realpath
import unittest

import confparse
from confparse import expand_config_path, load



class _Test(unittest.TestCase):

    """
    Work on settings in test/.testrc from test/sub/dir/
    """

    NAME = 'test'
    RC = 'testrc'
    PWD = 'test/sub/dir/'

    def _print_test_files(self):
        import os
        print getcwd()
        print os.popen('tree -a %s' % self.testdir).read()

    def setUp(self):
        self.testdir = join(dirname(tmpnam()), _Test.NAME)
        self.name = realpath(join(self.testdir, '.' + _Test.RC))
        self.pwd = join(self.testdir, _Test.PWD)
        makedirs(self.pwd)
        self.cwd = getcwd()
        chdir(self.pwd)
        open(self.name, 'w+').write("""\nfoo: \n     bar: {var: v}\n""")

    def tearDown(self):
        chdir(self.cwd)
        unlink(self.name)
        removedirs(self.pwd)

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

if __name__ == '__main__':
	unittest.main()

