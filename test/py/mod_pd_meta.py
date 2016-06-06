"""
One unit-test on the logic in pd-meta clean-mode
"""
import unittest
import os, sys

import pd_meta
from confparse import yaml_load, yaml_safe_dump, Values
from StringIO import StringIO


def V(**kw):
    return Values(kw)


class PdMeta(unittest.TestCase):

    """
    Simple access tests, structs are not nested
    """

    def setUp(self):
        self.pwd = os.getcwd()
        self.ctx = V(
            usage="",
            out=sys.stdout,
            err=sys.stderr,
            inp=sys.stdin,
            opts=V(
                flags=V(),
                cmds=[],
                args=V()
            )
        )

    cmd_clean_mode_specs = [ (
        # default, one arg
            V( args=V( prefix='myPrefix1', mode='' ), flags=V( quiet=False, strict=False ) ), (0, 'untracked')
        ), (
            V( args=V( prefix='myPrefix2', mode='' ), flags=V( quiet=False, strict=False ) ), (0, 'tracked')
        ), (
            V( args=V( prefix='myPrefix3', mode='' ), flags=V( quiet=False, strict=False ) ), (0, 'excluded')
        ),
# Raises assertion error
#        (
#            V( args=V( prefix='myPrefix1', mode='' ), flags=V( quiet=True, strict=False ) ), (0, '')
#        ), (
#            V( args=V( prefix='myPrefix2', mode='' ), flags=V( quiet=True, strict=False ) ), (0, '')
#        ), (
#            V( args=V( prefix='myPrefix3', mode='' ), flags=V( quiet=True, strict=False ) ), (0, '')
#        ),
        (
            V( args=V( prefix='myPrefix1', mode='tracked' ), flags=V( quiet=True, strict=False ) ), (0, '')
        ), (
            V( args=V( prefix='myPrefix2', mode='tracked' ), flags=V( quiet=True, strict=False ) ), (0, '')
        ), (
            V( args=V( prefix='myPrefix3', mode='tracked' ), flags=V( quiet=True, strict=False ) ), (0, '')
        ),
        (
            V( args=V( prefix='myPrefix1', mode='untracked' ), flags=V( quiet=False, strict=False ) ), (0, '')
        ), (
            V( args=V( prefix='myPrefix2', mode='untracked' ), flags=V( quiet=False, strict=False ) ), (1, '')
        ), (
            V( args=V( prefix='myPrefix3', mode='untracked' ), flags=V( quiet=False, strict=False ) ), (0, '')
        ),
        (
            V( args=V( prefix='myPrefix1', mode='excluded' ), flags=V( quiet=False, strict=False ) ), (1, '')
        ), (
            V( args=V( prefix='myPrefix2', mode='excluded' ), flags=V( quiet=False, strict=False ) ), (1, '')
        ), (
            V( args=V( prefix='myPrefix3', mode='excluded' ), flags=V( quiet=False, strict=False ) ), (0, '')
        ),
    ]
    cmd_clean_mode_data = V(
        repositories=V(
            myPrefix1=V(),
            myPrefix2=V(clean='tracked'),
            myPrefix3=V(clean='excluded')
        )
    )

    def test_1_cmd_clean_mode(self):
        ""
        for params, expected in self.cmd_clean_mode_specs:
            self.ctx.out = StringIO()
            self.ctx.opts = params
            ret = pd_meta.H_clean_mode(self.cmd_clean_mode_data, self.ctx)
            if not ret: ret = 0
            self.assertEquals( expected[0], ret, ("%s is not %s, for " % (ret, expected[0])) + yaml_safe_dump(params.todict()))
            self.assertEquals( self.ctx.out.getvalue().strip(), expected[1] )

    def tearDown(self):
        assert self.pwd == os.getcwd(), (self.pwd, os.getcwd())


def get_cases():
    return [
            PdMeta,
        ]


if __name__ == '__main__':
    unittest.main()


