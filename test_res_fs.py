import os
from os.path import join
import unittest

import confparse
import res
from res.fs import Dir, exclusive



cn = lambda o: o.__class__.__name__

dirs = [
        'd-1',
        'd-2',
        'd-2/d-2.1',
        'd-2/d-2.2'
    ]
files = [
        'f-1',
        'f-2',
        'd-1/f-1.1',
        'd-2/d-2.1/f-2.1.1',
        'd-2/d-2.2/f-2.2.1'
    ]

class ResFsTest(unittest.TestCase):

    testroot = '/tmp'

    def setUp(self):
        testid = "%s-%s" % ( cn(self), id(self) )
        for testdir in dirs:
            p = join( self.testroot, testid, testdir )
            if not os.path.exists( p ):
                os.makedirs( p )
        for testfile in files:
            p = join( self.testroot, testid, testfile )
            if not os.path.exists( p ):
                os.mknod( p )

    def test_1_exclusive(self):
        opts = confparse.Values(Dir.walk_opts.copy())
        opts.update(dict(dirs=False))
        assert not opts.dirs, opts
        assert not opts.files, opts
        assert not opts.symlinks, opts
        assert not opts.links, opts
        assert not opts.pipes, opts
        assert not opts.blockdevs, opts
        exclusive( opts, 'dirs files symlinks links pipes blockdevs' )
        assert not opts.dirs, opts
        assert opts.files, opts
        assert opts.symlinks, opts
        assert opts.links, opts
        assert opts.pipes, opts
        assert opts.blockdevs, opts

    def test_2_dir_walk(self):
        assert True
        testroot = join( self.testroot, "%s-%s" % ( cn(self), id(self) ) ) + os.sep
        # default: files and dirs
        opts = confparse.Values(Dir.walk_opts.copy())
        opts.update(dict(recurse=True))
        for walked in Dir.walk( testroot, opts ):
            p = walked.replace(testroot, '') 
            if p not in dirs:
                assert p in files, p
        # no dirs
        opts = confparse.Values(Dir.walk_opts.copy())
        opts.update(dict(dirs=False))
        for walked in Dir.walk( testroot, opts ):
            p = walked.replace(testroot, '') 
            assert p in files, p
        # no files
        opts.update(dict(files=False))
        for walked in Dir.walk( testroot, opts ):
            assert False, walked
        # only files
        opts = confparse.Values(Dir.walk_opts.copy())
        opts.update(dict(files=True))
        for walked in Dir.walk( testroot, opts ):
            p = walked.replace(testroot, '') 
            assert p in files, p

    def tearDown(self):
        pass


