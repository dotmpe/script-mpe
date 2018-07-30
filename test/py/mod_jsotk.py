"""
"""
import unittest
import os, sys
from StringIO import StringIO

from nose_parameterized import parameterized

from script_mpe import confparse, deep_eq, libcmd_docopt, jsotk, jsotk_lib



class AbstractKV:

    """
    These test are common to the two line-based key-value formats,
    and test the AbstractKVParser method `set_kv`.
    """

    Parser = None


    key_types_testdata = [
        ( 1, 'foo', dict ),
        ( 2, 'foo123', dict ),
        ( 3, '123', dict ),
        ( 4, '123foo', dict ),
    ]

    def abstract_scan_key_type(self, testnr, key, data_type ):

        d = self.Parser.get_data_instance(key)
        self.assert_(
                isinstance( d, data_type ),
                "Got %r instance instead of %r" % (
                    type( d ), data_type )
            )


    kv_testdata = [
        ( 1, None, 'rootkey=', {'rootkey': ''} ),
        ( 2, None, 'rootkey=null', {'rootkey': None} ),
        ( 3, None, 'rootkey={}', {'rootkey': {}} ),
        ( 7, {}, None, {} ),
        ( 8, {"foo":123}, None, {"foo":123} ),
    ]

    def abstract_key_value_parser_init(self, testnr, seed, rootkv, data):
        """
            flat-key-value parser init
        """
        parser = self.Parser(seed=seed, rootkey=rootkv)

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

    def abstract_key_value_parser_scan(self, testnr, seed, rootkv, data):
        """
            flat-key-value parses stream
        """
        parser = self.Parser(seed=seed, rootkey=rootkv)



class JsotkFlatKVParserTest(unittest.TestCase, AbstractKV):

    Parser = jsotk_lib.FlatKVParser


    key_types_testdata = AbstractKV.key_types_testdata + [
        ( 2, 'foo__', list ),
        ( 3, '__', list ),
        ( 4, 'foo__1', list ),
        ( 5, '__1', list ),
    ]

    @parameterized.expand(key_types_testdata)
    def test_flat_key_value_parser_type_scan(self, *args, **kwds):
        self.abstract_scan_key_type(*args, **kwds)


    kv_testdata = AbstractKV.kv_testdata + [
        # testnr, seed, rootkv, data
        ( 4, None, '__=', [''] ),
        ( 5, None, 'foo__=', {'foo':['']} ),
        ( 6, [], '__=', [''] ),
    ]

    @parameterized.expand(kv_testdata)
    def test_flat_key_value_parser_init(self, *args, **kwds):
        self.abstract_key_value_parser_init(*args, **kwds)

    @parameterized.expand(kv_testdata)
    def test_flat_key_value_parser_scan(self, *args, **kwds):
        self.abstract_key_value_parser_scan(*args, **kwds)



class JsotkPathKVParserTest(unittest.TestCase, AbstractKV):

    Parser = jsotk_lib.PathKVParser


    @parameterized.expand([
        ( 1, {}, '', '', '', False, {'':''} ),
        ( 2, {}, 'foo/bar', '', '', False, {'foo':{'bar':''}} ),
        ( 3, {}, 'foo[]', '', '', False, {'foo':['']}),
        ( 3, {}, 'foo[3]', '', '', False, {'foo':[None, None, '']}),
        # FIXME: ( 3, {}, 'foo[]/attr', '', None, True, {'foo':[{'attr':''}]}),
    ])
    def test_1_set(self, testnr, seed, key, value, default, values_as_json, expected):
        parser = self.Parser(seed=seed)
        parser.set(key, value, default=default, values_as_json=values_as_json)
        self.assertEquals(parser.data, expected)


    key_types_testdata = AbstractKV.key_types_testdata + [
        ( 5, 'foo[]', list ),
        ( 6, '[]', list ),
        ( 7, 'foo[1]', list ),
        ( 8, '[1]', list ),
        ( 9, 'foo[]', list ),
        ( 10, 'foo[3]', list ),
        ( 11, 'foo[]/att', dict ),
        ( 12, 'foo[7]/att', dict ),
    ]

    @parameterized.expand(key_types_testdata)
    def test_path_key_value_parser_type_scan(self, *args, **kwds):
        self.abstract_scan_key_type(*args, **kwds)


    kv_testdata = AbstractKV.kv_testdata + [
        # testnr, seed, rootkv, data
        ( 4, None, 'foo[]=', {'foo':['']} ),
        ( 5, None, '[]=', [''] ),
        # FIXME:   ( 5, None, '[]/foo={}', [{'foo':{}}] ),
        ( 6, None, '[]={}', [{}] ),
        ( 7, None, '[1]={}', [{}] ),
        ( 5, None, 'foo/2[2]=more', {'foo':{'2':[None,"more"]}} ),
    ]

    @parameterized.expand(kv_testdata)
    def test_path_key_value_parser_init(self, *args, **kwds):
        self.abstract_key_value_parser_init(*args, **kwds)

    @parameterized.expand(kv_testdata)
    def test_path_key_value_parser_scan(self, *args, **kwds):
        self.abstract_key_value_parser_scan(*args, **kwds)



class JsotkTest(unittest.TestCase):

    # FIXME: jsotk path indices need impl. fixed
    @parameterized.expand([
        ( 1, "baz", True),
        ( 2, "foo/bar", False),
        ( 3, "foo[0]/bar", True),
        #( 4, "foo[0][0]", False),
        ( 5, "baz/bar", True),
        #( 6, "[0]/bar", False)
    ])
    def test_data_check_path( self, testnr, pathexpr, expected ):

        """
        data-check-path should evalue path expression and return data
        """

        infile = StringIO('{"foo":[{"bar":null}]}')
        ctx = confparse.Values(dict(
            opts=libcmd_docopt.get_opts(jsotk.__usage__, argv=['path', '', pathexpr])
        ))

        self.assertEquals( ctx.opts.args.pathexpr, pathexpr )

        is_new = jsotk_lib.data_check_path( ctx, infile )

        self.assert_( is_new == expected, testnr )



# Return module test cases

def get_cases():
    return [
            JsotkFlatKVParserTest,
            JsotkPathKVParserTest,
            JsotkTest,
        ]

# Or start unittest

if __name__ == '__main__':
    unittest.main()
