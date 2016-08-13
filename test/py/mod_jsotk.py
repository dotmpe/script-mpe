"""
"""
import unittest
import os, sys
from StringIO import StringIO

from nose_parameterized import parameterized

import deep_eq
from script_mpe import confparse
from script_mpe import util
import jsotk, jsotk_lib



class JsotkPathKVParserTest(unittest.TestCase):

    @parameterized.expand([
        ( 1, None, 'rootkey=', {'rootkey': ''} ),
        ( 2, None, 'rootkey=null', {'rootkey': None} ),
        ( 3, None, 'rootkey={}', {'rootkey': {}} ),
        #( 4, None, '[]=', [''] ),
        #( 5, None, '[]/foo={}', [{}] ),
        #( 6, None, '[0]={}', [{}] ),
        ( 7, {}, None, {} ),
        ( 8, {"foo":123}, None, {"foo":123} ),
    ])
    def test_(self, testnr, seed, rootkv, data):
        parser = jsotk_lib.PathKVParser(seed=seed, rootkey=rootkv)

        self.assert_(
                isinstance( parser.data, type( data ) ),
                "%i: Got %r instance instead of %r" % (
                    testnr, type( parser.data ), type( data ) )
            )

        if rootkv != None:
            parser.set_kv(rootkv)

            eq = False
            try:
                eq = deep_eq.deep_eq( parser.data, data )
            except: pass
            self.assert_( eq, "%i: %r does not match %r" % ( testnr, parser.data, data ))


class JsotkTest(unittest.TestCase):

    # FIXME: jsotk path indices need impl. fixed
    @parameterized.expand([
        ( 1, "baz", True),
        ( 2, "foo/bar", False),
        #( 3, "foo[0]/bar", True),
        #( 4, "foo[0][0]", False),
        ( 5, "baz/bar", True),
        #( 6, "[0]/bar", False)
    ])
    def test_data_check_path( self, testnr, pathexpr, expected ):

        infile = StringIO('{"foo":[{"bar":null}]}')
        ctx = confparse.Values(dict(
            opts=util.get_opts(jsotk.__doc__, argv=['path', '', pathexpr])
        ))

        self.assertEquals( ctx.opts.args.pathexpr, pathexpr )

        is_new = jsotk_lib.data_check_path( ctx, infile )

        self.assert_( is_new == expected, testnr )


# Return module test cases

def get_cases():
    return [
            JsotkTest,
        ]

# Or start unittest

if __name__ == '__main__':
    unittest.main()

